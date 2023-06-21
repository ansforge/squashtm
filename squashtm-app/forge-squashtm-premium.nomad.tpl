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

            #artifact {
            #    source = "${repo_url}/artifactory/ext-tools/squash-tm/plugins/Jira_Cloud/${pluginbugtrackerjiracloud}"
             #   options {
              #      archive = false
               # }
            #}
			#Mise en place du trustore java avec les AC ANS
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

# Fichier de configuration log4j2
            template {
                change_mode = "restart"
                destination = "local/log4j2.xml"
                data = <<EOT
{{ with secret "forge/squashtm" }}{{.Data.data.log4j2}}{{end}}
EOT
            }

# Ajout d'une confifguration pour le proxy sortant
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
extra_hosts = ["squashtm.db.internal:$\u007BNOMAD_IP_http\u007D"]
                mount {
                    type = "volume"
                    target = "/opt/squash-tm"
                    source = "squash_app"
                    readonly = false
                    volume_options {
                        no_copy = false
                        driver_config {
                            name = "pxd"
                            options {
                                io_priority = "high"
                                size = 2
                                repl = 1
                            }
                        }
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

               # mount {
                #    type = "bind"
                 #   target = "/opt/squash-tm/plugins/${pluginbugtrackerjiracloud}"
                 #   source = "local/${pluginbugtrackerjiracloud}"
                  #  readonly = true
                  #  bind_options {
                   #     propagation = "rshared"
                   # }
                #}
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
    }
}