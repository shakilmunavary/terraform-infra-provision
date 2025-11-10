@Library('aiLib') _

pipeline {
    agent any

    environment {
        WORKDIR = "${env.WORKSPACE}"
        SHARED_LIB_DIR = "jenkins-shared-ai-lib"
        REPO_NAME = "terraform-infra-provision"
    }

    options {
        skipDefaultCheckout()
    }

    stages {
        stage("Clean Workspace") {
            steps {
                cleanWs(deleteDirs: true)
            }
        }

        stage("Terraform Init & Plan") {
            steps {
                dir("${WORKDIR}/terraform") {
                    sh """
                        terraform init
                        terraform plan -out=tfplan.binary
                        terraform show -json tfplan.binary > tfplan.raw.json
                        jq '.planned_values.root_module.resources + (.planned_values.root_module.child_modules[]?.resources // [])' tfplan.raw.json > tfplan.json
                        mv tfplan.json ../tfplan.json
                    """
                }
            }
        }

        stage("AI Analytics") {
            steps {
                withCredentials([
                    string(credentialsId: 'AZURE_API_KEY', variable: 'AZURE_API_KEY'),
                    string(credentialsId: 'AZURE_API_BASE', variable: 'AZURE_API_BASE')
                ]) {
                    sh """
                        echo '🔥 Purging stale Python caches'
                        find ${SHARED_LIB_DIR} -name '*.pyc' -delete
                        find ${SHARED_LIB_DIR} -name '__pycache__' -type d -exec rm -rf {} +

                        echo '🔍 Verifying active indexer.py version'
                        head -n 5 ${SHARED_LIB_DIR}/indexer.py
                    """

                    aiAnalytics(
                        workdir: "${WORKDIR}",
                        sharedLibDir: "${SHARED_LIB_DIR}",
                        repoName: "${REPO_NAME}",
                        buildNumber: "${BUILD_NUMBER}"
                    )
                }
            }
        }

        stage("Publish AI Analysis Report") {
            steps {
                publishHTML(target: [
                    reportDir: "${WORKDIR}",
                    reportFiles: 'output.html',
                    reportName: 'AI Analysis'
                ])
            }
        }

        stage("Approve Stage") {
            when {
                expression {
                    def coverage = sh(
                        script: "grep -i 'Overall Guardrail Coverage' ${WORKDIR}/output.html | grep -o '[0-9]\\{1,3\\}%'",
                        returnStdout: true
                    ).trim().replace('%','').toInteger()
                    return coverage >= 80
                }
            }
            steps {
                echo "✅ Guardrail coverage is sufficient. Proceeding to approval."
            }
        }

        stage("Reject Stage") {
            when {
                expression {
                    def coverage = sh(
                        script: "grep -i 'Overall Guardrail Coverage' ${WORKDIR}/output.html | grep -o '[0-9]\\{1,3\\}%'",
                        returnStdout: true
                    ).trim().replace('%','').toInteger()
                    return coverage < 80
                }
            }
            steps {
                echo "❌ Guardrail coverage is insufficient. Rejecting deployment."
                error("Deployment rejected due to low guardrail coverage.")
            }
        }

        stage("Cleanup Vector DB") {
            steps {
                sh """
                    . venv/bin/activate
                    python3 ${SHARED_LIB_DIR}/delete_namespace.py \
                      --namespace ${REPO_NAME}-${BUILD_NUMBER}
                """
            }
        }
    }
}
