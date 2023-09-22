job "forge-squashtm-premium" {
    datacenters = ["${datacenter}"]
    type = "service"

    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "squashtm-server" {
        count ="1"
        
        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }
        
        constraint {
            attribute = "$\u007Bnode.class\u007D"
            value     = "data"
        }

        network {
            port "http" { to = 8080 }
        }

        task "squashtm" {
            driver = "docker"

            # log-shipper
            leader = true 

            artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/Jira_Cloud/${pluginjaxbapi}"
                options {
                    archive = false
                }
            }

            artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/Jira_Cloud/${pluginjaxbimpl}"
                options {
                    archive = false
                }
            }

            artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/Jira_Cloud/${pluginbugtrackerjiracloud}"
                options {
                    archive = false
                }
            }
			
			# plugin LDAP sur Artifactory
			 artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/ldap/${pluginsecurityldap}"
                options {
                    archive = false
                }
            }
			artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/ldap/${pluginspringldapcore}"
                options {
                    archive = false
                }
            }
			artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/ldap/${pluginspringsecurityldap}"
                options {
                    archive = false
                }
            }
			artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/admin/${pluginapirestadmin}"
                options {
                    archive = false
                }
            }

            # Récupération du fichier log4j sur Artifactory
            artifact {
                source = "${repo_url}/artifactory/ext-tools/squash-tm/conf/5.0.x/log4j2.xml"
                options {
                    archive = false
                }
            }

            # Mise en place du trustore java avec les AC ANS
            artifact {
                source = "${repo_url}/artifactory/asip-ac/truststore/cacerts"
                options {
                    archive = false
                }
            }

            template {
                data = <<EOH
SQTM_DB_TYPE=postgresql
SQTM_DB_HOST={{ range service "forge-squashtm-postgresql" }}{{.Address}}{{ end }}
SQTM_DB_PORT={{ range service "forge-squashtm-postgresql" }}{{.Port}}{{ end }}
{{ with secret "forge/squashtm" }}
SQTM_DB_NAME={{ .Data.data.sqtm_db_name }}
SQTM_DB_USERNAME={{ .Data.data.sqtm_db_username }}
SQTM_DB_PASSWORD={{ .Data.data.sqtm_db_password }}
{{ end }}
                EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            template {
                data = <<EOH
{{ with secret "forge/squashtm" }}{{ .Data.data.sqtm_licence }}{{ end }}
EOH
                destination = "secret/squash-tm.lic"
                change_mode = "restart"
            }
			
			# Ajout configuration LDAP dans squash.tm.cfg
			template {
                data = <<EOH
{{ with secret "forge/squashtm" }}{{ .Data.data.sqtm_cfg }}{{ end }}
EOH
                destination = "secret/squash.tm.cfg.properties"
                change_mode = "restart"
            }

            # Ajout d'une configuration pour le proxy sortant
            template {
                data = <<EOH
JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Dhttps.proxyHost=${url_proxy_sortant_https_host} -Dhttps.proxyPort=${url_proxy_sortant_https_port} -Dhttp.proxyHost=${url_proxy_sortant_http_host} -Dhttp.proxyPort=${url_proxy_sortant_http_port} -Dhttp.nonProxyHosts=${url_proxy_sortant_no_proxy}"
                EOH
                destination = "local/java.env"
                change_mode = "restart"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["http"]

                mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/license/squash-tm.lic"
                    source = "secret/squash-tm.lic"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }
				
				 # Fichier de configuration squash.tm.cfg
                mount {
                   type = "bind"
                    target = "/opt/squash-tm/conf/squash.tm.cfg.properties"
                    source = "secret/squash.tm.cfg.properties"
                    readonly = false
                    bind_options {
                       propagation = "rshared"
                    }
                }

                # Fichier de configuration log4j2
                mount {
                    type = "bind"
                    target = "/opt/squash-tm/conf/log4j2.xml"
                    source = "local/log4j2.xml"
                    readonly = false
                    bind_options {
                        propagation = "rshared"
                    }
                }

                mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginjaxbapi}"
                    source = "local/${pluginjaxbapi}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }

                mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginjaxbimpl}"
                    source = "local/${pluginjaxbimpl}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }

                mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginbugtrackerjiracloud}"
                    source = "local/${pluginbugtrackerjiracloud}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
				
				mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginsecurityldap}"
                    source = "local/${pluginsecurityldap}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
				mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginspringldapcore}"
                    source = "local/${pluginspringldapcore}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
				mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginspringsecurityldap}"
                    source = "local/${pluginspringsecurityldap}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
				mount {
                    type = "bind"
                    target = "/opt/squash-tm/plugins/${pluginapirestadmin}"
                    source = "local/${pluginapirestadmin}"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                }
                # Trustore java contenant les AC ANS
                mount {
                    type = "bind"
                    target = "/opt/java/openjdk/lib/security/cacerts"
                    source = "local/cacerts"
                    readonly = true
                    bind_options {
                        propagation = "rshared"
                    }
                } 
            }
            resources {
                cpu    = 600
                memory = 4096
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-${servername_squash}/"]
                port = "http"
                check {
                    name     = "alive"
                    type     = "http"
                    path     = "/squash"
                    interval = "60s"
                    timeout  = "5s"
                    port     = "http"
                }
            }
        }

        # log-shipper
        task "log-shipper" {
            driver = "docker"
            restart {
                    interval = "3m"
                    attempts = 5
                    delay    = "15s"
                    mode     = "delay"
            }
            meta {
                INSTANCE = "$\u007BNOMAD_ALLOC_NAME\u007D"
            }
            template {
                data = <<EOH
REDIS_HOSTS = {{ range service "PileELK-redis" }}{{ .Address }}:{{ .Port }}{{ end }}
PILE_ELK_APPLICATION = SQUASHTM 
EOH
                destination = "local/file.env"
                change_mode = "restart"
                env = true
            }
            config {
                image = "ans/nomad-filebeat:8.2.3-2.0"
            }
            resources {
                cpu    = 100
                memory = 150
            }
        } #end log-shipper 

    }
}
