terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" } # data.tls_certificate 需要
  }
}

# 這三個用來限制是哪個 GitHub repo/分支可假設角色
variable "github_owner" {
  type = string
}                         # 例如 "your-org-or-user"

variable "github_repo" {
  type = string
}                      # 例如 "your-repo"
variable "github_branch" {
  type    = string
  default = "main"
}

locals {
  gh_sub_branch = "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_branch}"
  # 如果也想允許打 tag 觸發，加入下面這個（可選）
  gh_sub_tags   = "repo:${var.github_owner}/${var.github_repo}:ref:refs/tags/v*.*.*"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 若帳號還沒有 OIDC Provider，就由 Terraform 建立；已有的話改用 import（見下方）
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# 信任政策（限制為指定 repo/分支）
data "aws_iam_policy_document" "gh_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # 只允許 main；若也允許 tag，改用 StringLike 並把 values 換成 [local.gh_sub_branch, local.gh_sub_tags]
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.gh_sub_branch]
    }
  }
}

resource "aws_iam_role" "gh_actions_ecr" {
  name               = "github-actions-ecr-pusher"
  assume_role_policy = data.aws_iam_policy_document.gh_trust.json
}

# 低權限 ECR Push（可先用 *，之後再收斂到特定 repo ARN）
data "aws_iam_policy_document" "ecr_push" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "github-actions-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.gh_actions_ecr.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

output "gh_actions_role_arn" {
  value = aws_iam_role.gh_actions_ecr.arn
}
