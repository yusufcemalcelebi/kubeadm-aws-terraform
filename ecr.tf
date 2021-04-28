resource "aws_ecr_repository" "assignment_repo" {
  name                 = "assignment_repo"
  image_tag_mutability = "MUTABLE"
}