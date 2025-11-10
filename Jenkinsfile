@Library('aiLib') _

pipeline {
    agent any

    environment {
        TF_BASE_DIR     = "/home/AI-SDP-PLATFORM/terra-analysis"
        SHARED_LIB_REPO = "https://github.com/shakilmunavary/jenkins-shared-ai-lib.git"
        SHARED_LIB_DIR  = "jenkins-shared-ai-lib"
    }

    stages {
        stage('Initialize') {
            steps {
                script {
                    def repoUrl = env.GIT_URL ?: "https://github.com/shakilmunavary/terraform-ai-analytics.git"
                    def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                    def workDir = "${env.TF_BASE_DIR}/${repoName}"

                    env.REPO_NAME = repoName
                    env.REPO_URL  = repoUrl
                    env.WORKDIR   = workDir
                    env.TF_STATE  = "${workDir}/terraform.tfstate"
                }
            }
        }

        stage('Clone Terraform Repo') {
            steps {
                sh """
                    echo "📦 Cloning ${REPO_NAME} from ${REPO_URL}"
                    rm -rf ${REPO_NAME}
                    git clone ${REPO_URL}
                    mkdir -p ${WORKDIR}
                    cp -r ${REPO_NAME}/* ${WORKDIR}/
                """
            }
        }

        stage('Clone Shared AI Library') {
            steps {
                sh """
                    echo "📦 Cloning Shared AI Library"
                    rm -rf ${SHARED_LIB_DIR}
                    git clone ${SHARED_LIB_REPO}
                """
            }
        }

        stage('Download Terraform State File from S3') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    script {
                        def s3Key = "${env.REPO_NAME}/${env.REPO_NAME}.state"
                        def localPath = "${env.TF_STATE}"

                        sh """
                            echo "📥 Checking for tfstate file in S3..."
                            if aws s3 ls s3://ai-terraform-state-file/${s3Key}; then
                                aws s3 cp s3://ai-terraform-state-file/${s3Key} ${localPath}
                                echo "✅ tfstate file downloaded to ${localPath}"
                            else
                                echo "⚠️ No tfstate file found in S3. Proceeding without it."
                            fi
                        """
                    }
                }
            }
        }

        stage('Fix Workspace Ownership') {
            steps {
                sh """
                    echo "🔧 Ensuring Jenkins owns the workspace"
                    sudo chown -R jenkins:jenkins ${env.WORKDIR}/terraform || true
                """
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                dir("${env.WORKDIR}/terraform") {
                    withCredentials([
                        string(credentialsId: 'INFRACOST_APIKEY', variable: 'INFRACOST_API_KEY')
                    ]) {
                        sh """
                            echo "🚀 Running terraform init and plan"
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
                            "${env.WORKDIR}/terraform/tfplan.json",
                            "${env.SHARED_LIB_DIR}/guardrails/guardrails_v1.txt",
                            "${env.SHARED_LIB_DIR}/reference_terra_analysis_html.html",
                            "${env.WORKDIR}/output.html",
                            "${env.WORKDIR}/payload.json",
                            AZURE_API_KEY,
                            AZURE_API_BASE,
                            DEPLOYMENT_NAME,
                            AZURE_API_VERSION
                        )
                    }
                }
            }
        }

        stage('Publish AI Analysis Report') {
            steps {
                publishHTML([
                    reportName: 'AI Analysis',
                    reportDir: "${env.WORKDIR}",
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
                    def passCount = sh(
                        script: "grep -o 'class=\"pass\"' ${env.WORKDIR}/output.html | wc -l",
                        returnStdout: true
                    ).trim().toInteger()

                    def failCount = sh(
                        script: "grep -o 'class=\"fail\"' ${env.WORKDIR}/output.html | wc -l",
                        returnStdout: true
                    ).trim().toInteger()

                    def totalCount = passCount + failCount
                    def coveragePercent = totalCount > 0 ? (passCount * 100 / totalCount).toInteger() : 0

                    echo "🔍 Guardrail Coverage Detected: ${coveragePercent}%"

                    sh "sed -i 's/Overall Guardrail Coverage: .*/Overall Guardrail Coverage: ${coveragePercent}%/' ${env.WORKDIR}/output.html"

                    if (coveragePercent >= 50) {
                        currentBuild.description = "Auto-approved (Coverage: ${coveragePercent}%)"
                        env.PIPELINE_DECISION = 'APPROVED'
                    } else {
                        currentBuild.description = "Auto-rejected (Coverage: ${coveragePercent}%)"
                        env.PIPELINE_DECISION = 'REJECTED'
                    }
                }
            }
        }

        stage('Approve Stage') {
            when {
                expression { env.PIPELINE_DECISION == 'APPROVED' }
            }
            steps {
                echo "✅ Pipeline approved. Proceeding with deployment or next steps..."
            }
        }

        stage('Reject Stage') {
            when {
                expression { env.PIPELINE_DECISION == 'REJECTED' }
            }
            steps {
                echo "❌ Pipeline rejected. Halting further actions."
            }
        }
    }
}
