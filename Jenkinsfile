@Library('aiLib') _

pipeline {
    agent any

    environment {
        TF_REPO_URL     = "${env.GIT_URL ?: 'https://github.com/shakilmunavary/terraform-infra-provision.git'}"
        SHARED_LIB_REPO = "https://github.com/shakilmunavary/jenkins-shared-ai-lib.git"
    }

    stages {
        stage('Clone Repos') {
            steps {
                sh """
                    echo "📦 Cloning Terraform Repo"
                    rm -rf terraform-infra-provision
                    git clone ${TF_REPO_URL}

                    echo "📦 Cloning Shared AI Library"
                    rm -rf jenkins-shared-ai-lib
                    git clone ${SHARED_LIB_REPO}
                """
            }
        }

        stage('Download tfstate from S3') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        echo "📥 Checking for tfstate file in S3..."
                        if aws s3 ls s3://ai-terraform-state-file/terraform-infra-provision/terraform-infra-provision.state; then
                            aws s3 cp s3://ai-terraform-state-file/terraform-infra-provision/terraform-infra-provision.state terraform-infra-provision/terraform/terraform.tfstate
                            echo "✅ tfstate downloaded"
                        else
                            echo "⚠️ No tfstate found. Proceeding without it."
                        fi
                    """
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                dir('terraform-infra-provision/terraform') {
                    withCredentials([
                        string(credentialsId: 'INFRACOST_APIKEY', variable: 'INFRACOST_API_KEY')
                    ]) {
                        sh """
                            terraform init
                            terraform plan -out=tfplan.binary
                            terraform show -json tfplan.binary > tfplan.raw.json

                            jq '
                              .resource_changes |= sort_by(.address) |
                              del(.resource_changes[].change.after_unknown) |
                              del(.resource_changes[].change.before_sensitive) |
                              del(.resource_changes[].change.after_sensitive) |
                              del(.resource_changes[].change.after_identity) |
                              del(.resource_changes[].change.before) |
                              del(.resource_changes[].change.after.tags_all) |
                              del(.resource_changes[].change.after.tags) |
                              del(.resource_changes[].change.after.id) |
                              del(.resource_changes[].change.after.arn)
                            ' tfplan.raw.json > tfplan.json

                            infracost configure set api_key \$INFRACOST_API_KEY
                            infracost breakdown --path=tfplan.binary --format json --out-file totalcost.json
                        """
                    }
                }
            }
        }

        stage('AI Analytics') {
            steps {
                withCredentials([
                    string(credentialsId: 'AZURE_API_KEY', variable: 'AZURE_API_KEY'),
                    string(credentialsId: 'AZURE_API_BASE', variable: 'AZURE_API_BASE'),
                    string(credentialsId: 'AZURE_DEPLOYMENT_NAME', variable: 'DEPLOYMENT_NAME'),
                    string(credentialsId: 'AZURE_API_VERSION', variable: 'AZURE_API_VERSION')
                ]) {
                    script {
                        aiAnalytics(
                            "terraform-infra-provision/terraform/tfplan.json",
                            "jenkins-shared-ai-lib/guardrails/guardrails_v1.txt",
                            "jenkins-shared-ai-lib/reference_terra_analysis_html.html",
                            "terraform-infra-provision/terraform/output.html",
                            "terraform-infra-provision/terraform/payload.json",
                            AZURE_API_KEY,
                            AZURE_API_BASE,
                            DEPLOYMENT_NAME,
                            AZURE_API_VERSION
                        )
                    }
                }
            }
        }

        stage('Publish Report') {
            steps {
                publishHTML([
                    reportName: 'AI Analysis',
                    reportDir: 'terraform-infra-provision/terraform',
                    reportFiles: 'output.html',
                    keepAll: true,
                    allowMissing: false,
                    alwaysLinkToLastBuild: true
                ])
            }
        }

        stage('Evaluate Guardrail Coverage') {
            steps {
                script {
                    def passCount = sh(script: "grep -o 'class=\"pass\"' terraform-infra-provision/terraform/output.html | wc -l", returnStdout: true).trim().toInteger()
                    def failCount = sh(script: "grep -o 'class=\"fail\"' terraform-infra-provision/terraform/output.html | wc -l", returnStdout: true).trim().toInteger()
                    def coverage = passCount + failCount > 0 ? (passCount * 100 / (passCount + failCount)).toInteger() : 0

                    echo "🔍 Guardrail Coverage: ${coverage}%"
                    sh "sed -i 's/Overall Guardrail Coverage: .*/Overall Guardrail Coverage: ${coverage}%/' terraform-infra-provision/terraform/output.html"

                    env.PIPELINE_DECISION = coverage >= 50 ? 'APPROVED' : 'REJECTED'
                    currentBuild.description = "Auto-${env.PIPELINE_DECISION.toLowerCase()} (Coverage: ${coverage}%)"
                }
            }
        }

        stage('Decision') {
            steps {
                script {
                    if (env.PIPELINE_DECISION == 'APPROVED') {
                        echo "✅ Pipeline approved. Proceeding..."
                    } else {
                        echo "❌ Pipeline rejected. Halting..."
                    }
                }
            }
        }
    }
}
