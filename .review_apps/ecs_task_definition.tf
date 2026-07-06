locals {
  logs_stream_prefix = "${data.terraform_remote_state.review.outputs.review_apps_log_group_name}/forms-runner/pr-${var.pull_request_number}"

  runner_review_app_hostname = "pr-${var.pull_request_number}.submit.review.forms.service.gov.uk"

  # Admin has it's own hostname because it needs to be user facing too,
  # but it cannot be on a subdomain of the runner review app's hostname
  # because we use a wildcard certificate of the form "*.submit.review.forms.service.gov.uk".
  # Subject Alternative Names on certificates can only contain one wildcard,
  # and the wildcard can only match a single label (i.e. "y." but not "x.y.")
  admin_app_hostname = "pr-${var.pull_request_number}-admin.submit.review.forms.service.gov.uk"

  forms_runner_env_vars = [
    { name = "DATABASE_URL", value = "postgres://postgres:postgres@127.0.0.1:5432/forms-runner" },
    { name = "GOVUK_APP_DOMAIN", value = "publishing.service.gov.uk" },
    { name = "PORT", value = "3001" },
    { name = "QUEUE_DATABASE_URL", value = "postgres://postgres:postgres@127.0.0.1:5432/forms-runner-queue" },
    { name = "RAILS_DEVELOPMENT_HOSTS", value = local.runner_review_app_hostname },
    { name = "RAILS_ENV", value = "production" },
    { name = "REDIS_URL", value = "redis://localhost:6379/" },
    { name = "SECRET_KEY_BASE", value = "unsecured_secret_key_material" },
    { name = "SETTINGS__ANALYTICS_ENABLED", value = "false" },
    { name = "SETTINGS__CLOUDWATCH_METRICS_ENABLED", value = "false" },
    { name = "SETTINGS__FORMS_ADMIN__BASE_URL", value = "https://${local.admin_app_hostname}" },
    { name = "SETTINGS__FORMS_API__BASE_URL", value = "http://localhost:3000" },
    { name = "SETTINGS__FORMS_ENV", value = "review" },
    { name = "SETTINGS__FEATURES__FILLER_ANSWER_EMAIL_ENABLED", value = "true" }

    ##
    # Settings for AWS SES email sending, and S3 CSV submission and file upload
    # are deliberately omitted here.
    #
    # We aren't enabling them for review apps for the time being.
    ##
  ]

  forms_admin_env_vars = [
    { name = "DATABASE_URL", value = "postgres://postgres:postgres@127.0.0.1:5432" },
    { name = "GOVUK_APP_DOMAIN", value = "publishing.service.gov.uk" },
    { name = "EMAIL", value = "review-app-submissions@review.forms.service.gov.uk" },
    { name = "PORT", value = "3000" },
    { name = "RAILS_DEVELOPMENT_HOSTS", value = local.admin_app_hostname },
    { name = "RAILS_ENV", value = "production" },
    { name = "SECRET_KEY_BASE", value = "unsecured_secret_key_material" },
    { name = "SETTINGS__ACT_AS_USER_ENABLED", value = "true" },
    { name = "SETTINGS__AUTH_PROVIDER", value = "developer" },
    { name = "SETTINGS__FORMS_ENV", value = "review" },
    { name = "SETTINGS__FORMS_RUNNER__URL", value = "https://${local.runner_review_app_hostname}" },
    { name = "ALLOWED_HOST_PATTERNS", value = "localhost:3000" },
    { name = "SETTINGS__FEATURES__DESCRIBE_NONE_OF_THE_ABOVE_ENABLED", value = "true" }
  ]
}

resource "aws_ecs_task_definition" "task" {
  family = "forms-runner-pr-${var.pull_request_number}"

  network_mode = "awsvpc"
  cpu          = 256
  memory       = 1024

  requires_compatibilities = ["FARGATE"]

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  execution_role_arn = data.terraform_remote_state.review.outputs.ecs_task_execution_role_arn

  container_definitions = jsonencode([

    # forms-runner
    {
      name                   = "forms-runner"
      image                  = var.forms_runner_container_image
      command                = []
      essential              = true
      environment            = local.forms_runner_env_vars
      readonlyRootFilesystem = true

      dockerLabels = {
        "traefik.http.middlewares.forms-runner-pr-${var.pull_request_number}.basicauth.users" : data.terraform_remote_state.review.outputs.traefik_basic_auth_credentials

        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}.rule" : "Host(`${local.runner_review_app_hostname}`)",
        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}.service" : "forms-runner-pr-${var.pull_request_number}",
        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}.middlewares" : "forms-runner-pr-${var.pull_request_number}@ecs"

        "traefik.http.services.forms-runner-pr-${var.pull_request_number}.loadbalancer.server.port" : "3001",
        "traefik.http.services.forms-runner-pr-${var.pull_request_number}.loadbalancer.healthcheck.path" : "/up",
        "traefik.enable" : "true",
      },

      portMappings = [
        {
          containerPort = 3001
          hostPort      = 3001
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/forms-runner"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -O - 'http://localhost:3001/up' || exit 1"]
        interval    = 30
        retries     = 5
        startPeriod = 180
        timeout     = 5
      }

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "redis"
          condition     = "HEALTHY"
        },
        {
          containerName = "forms-runner-seeding",
          condition     = "SUCCESS"
        },
      ]
    },

    # forms-admin
    {
      name                   = "forms-admin"
      image                  = "711966560482.dkr.ecr.eu-west-2.amazonaws.com/forms-admin-deploy:latest"
      command                = []
      essential              = true
      environment            = local.forms_admin_env_vars
      readonlyRootFilesystem = true

      dockerLabels = {
        "traefik.http.middlewares.forms-runner-pr-${var.pull_request_number}-admin-app.basicauth.users" : data.terraform_remote_state.review.outputs.traefik_basic_auth_credentials

        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}-admin-app.rule" : "Host(`${local.admin_app_hostname}`)",
        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}-admin-app.service" : "forms-runner-pr-${var.pull_request_number}-admin-app",
        "traefik.http.routers.forms-runner-pr-${var.pull_request_number}-admin-app.middlewares" : "forms-runner-pr-${var.pull_request_number}-admin-app@ecs"

        "traefik.http.services.forms-runner-pr-${var.pull_request_number}-admin-app.loadbalancer.server.port" : "3000",
        "traefik.http.services.forms-runner-pr-${var.pull_request_number}-admin-app.loadbalancer.healthcheck.path" : "/up",
        "traefik.enable" : "true",
      },


      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/forms-admin"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -O - 'http://localhost:3000/up' || exit 1"]
        interval    = 30
        retries     = 5
        startPeriod = 180
        timeout     = 5
      }

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        },
        {
          containerName = "forms-admin-seeding",
          condition     = "SUCCESS"
        }
      ]
    },

    # postgres
    {
      name      = "postgres"
      image     = "public.ecr.aws/docker/library/postgres:16.6"
      command   = []
      essential = true

      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      environment = [
        { name = "POSTGRES_PASSWORD", value = "postgres" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/postgres"
        }
      }

      healthCheck = {
        command  = ["CMD-SHELL", "psql -h localhost -p 5432 -U postgres -c \"SELECT current_timestamp - pg_postmaster_start_time();\""]
        interval = 30
        retries  = 3
        timeout  = 5
      }
    },

    # redis
    {
      name  = "redis",
      image = "public.ecr.aws/docker/library/redis:latest",
      command = [
        "redis-server",
        "--appendonly",
        "yes"
      ],
      essential = true

      portMappings = [
        {
          containerPort = 6379
          hostPort      = 6379
          protocol      = "tcp"
        }
      ]

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/redis"
        }
      }

      healthCheck = {
        command  = ["CMD-SHELL", "redis-cli", "ping"]
        interval = 30
        retries  = 3
        timeout  = 5
      }
    },

    # forms-runner-seeding
    {
      name                   = "forms-runner-seeding"
      image                  = var.forms_runner_container_image
      command                = ["rake", "db:create", "db:migrate", "db:seed"]
      essential              = false
      environment            = local.forms_runner_env_vars
      readonlyRootFilesystem = true

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/forms-runner-seeding"
        }
      }

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        }
      ]
    },

    # forms-admin-seeding
    {
      name                   = "forms-admin-seeding"
      image                  = "711966560482.dkr.ecr.eu-west-2.amazonaws.com/forms-admin-deploy:latest"
      command                = ["rake", "db:setup"]
      essential              = false
      environment            = local.forms_admin_env_vars
      readonlyRootFilesystem = true

      mountPoints    = []
      systemControls = []
      volumesFrom    = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = data.terraform_remote_state.review.outputs.review_apps_log_group_name
          awslogs-region        = "eu-west-2"
          awslogs-stream-prefix = "${local.logs_stream_prefix}/forms-admin-seeding"
        }
      }

      dependsOn = [
        {
          containerName = "postgres"
          condition     = "HEALTHY"
        }
      ]
    },
  ])
}
