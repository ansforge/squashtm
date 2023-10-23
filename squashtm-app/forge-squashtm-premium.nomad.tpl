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

            # Ajout d'une configuration pour le proxy sortant
            template {
                data = <<EOH
JAVA_TOOL_OPTIONS="-Djava.awt.headless=true -Dhttps.proxyHost=${url_proxy_sortant_https_host} -Dhttps.proxyPort=${url_proxy_sortant_https_port} -Dhttp.proxyHost=${url_proxy_sortant_http_host} -Dhttp.proxyPort=${url_proxy_sortant_http_port} -Dhttp.nonProxyHosts=${url_proxy_sortant_no_proxy}"
                EOH
                destination = "local/java.env"
                change_mode = "restart"
                env = true
            }

            # Ajout d'une configuration pour LDAP
            template {
                data = <<EOH
# CONFIGURATION MANAGEMENT
spring.profiles.include=

# EMBEDDED SERVER CONFIGURATION
###############################
# In HTTPS environments, allows to make sure the internal redirections use the HTTPS protocol
server.tomcat.use-relative-redirects=true

# REPORTS
#########
report.criteria.project.multiselect=false

# BUGTRACKER CONNECTORS
#######################
squashtm.bugtracker.timeout=15

# ADMIN FEATURE CONFIGURATION
#############################
# !!!! PLEASE READ THE DOCUMENTATION ABOUT THIS FEATURE BEFORE ACTIVATING IT !!!
squashtm.feature.file.repository = false
# This can represent a security leak, but ease problems resolution by allow users to provide stack traces to Henix support
squashtm.stack.trace.control.panel.visible = false

# CONFIGURATION FOR XSQUASH4JIRA PLUGIN
#######################################
# if not provided will be defaulted to 300 sec ie 5 minutes
squash.external.synchronisation.delay = 300
# Size of the batch size for jira rest API.
plugin.synchronisation.jira.batchSize = 50

# AUTHENTICATION CONFIGURATION FOR SINGLE LDAP
###################################################
# Defines the authentication provider
authentication.provider=ldap
# declare the ldap server url
authentication.ldap.server.url=ldap://{{ range service "openldap-forge" }}{{.Address}}:{{.Port}}{{ end }}
# when ldap directory cannot be accessed anonymously, configure the 'manager' user DN and password
authentication.ldap.server.managerDn=cn=Manager,dc=asipsante,dc=fr
{{ with secret "forge/squashtm" }}
authentication.ldap.server.managerPassword={{ .Data.data.ldap_admin_password }}
{{ end }}
# configure a search base dn and a search query
authentication.ldap.user.searchBase=dc=asipsante,dc=fr
authentication.ldap.user.searchFilter=(uid={0})
# Uncomment the following property when a user cannot read its own directory node.
authentication.ldap.user.fetchAttributes=true


                EOH
                destination = "secret/squash.tm.cfg.properties"
                change_mode = "restart"
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

                # Ajout d'une configuration pour LDAP
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