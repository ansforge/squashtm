project = "forge/squashtm-db"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/squashtm.git"
        ref  = "var.datacenter"
        path = "squashtm-db"
        ignore_changes_outside_path = true
    }
}

app "forge/squashtm-db" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/forge-squashtm-postgresql.nomad.tpl", {
            image   = var.image
            tag     = var.tag
            datacenter = var.datacenter
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "test"
}

variable "image" {
    type    = string
    default = "postgres"
}

variable "tag" {
    type    = string
    default = "13.5"
}
