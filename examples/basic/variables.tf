variable "sequential_number" {
  description = "Sequential number used when deploying multiple instances"
  type = string
  validation {
    condition     = can(regex("^\\d\\d$", var.sequential_number))
    error_message = "The sequential_number must be a 2 digit number as a string."
  }
  default = "01"
}
