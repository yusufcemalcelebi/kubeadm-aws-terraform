resource "aws_ecr_repository" "result_repo" {
  name                 = "result"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "vote_repo" {
  name                 = "vote"
  image_tag_mutability = "MUTABLE"
}

resource "aws_ecr_repository" "worker_repo" {
  name                 = "worker"
  image_tag_mutability = "MUTABLE"
}