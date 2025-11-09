pipeline {
    agent any

    stages {
        stage('Initialize') {
            steps {
                script {
                    // Dynamically infer repo name from JOB_NAME
                    def repoName = env.JOB_NAME.tokenize('/').last()
                    def repoUrl  = "https://github.com/your-org/${repoName}.git"
                    def workDir  = "/home/AI-SDP-PLATFORM/terra-analysis/${repoName}"

                    // Save for later stages
                    env.REPO_NAME = repoName
                    env.REPO_URL  = repoUrl
                    env.WORKDIR   = workDir
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

        stage('Download Terraform State File from S3') {
            steps {
                script {
                    def s3Key = "${env.REPO_NAME}/${env.REPO_NAME}.state"
                    def localPath = "${env.WORKDIR}/terraform.tfstate"

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

        stage('Terraform Init & Plan') {
            steps {
                dir("${env.WORKDIR}") {
                    sh """
                        echo "🔍 Running terraform fmt and validate"
                        terraform fmt -check
                        terraform validate

                        echo "🚀 Initializing Terraform with S3 backend"
                        terraform init

                        echo "📦 Running Terraform Plan"
                        terraform plan -out=tfplan.binary
                    """
                }
            }
        }
    }
}
