pipeline {
    agent any

    stages {
        stage('Initialize') {
            steps {
                script {
                    def repoUrl = env.GIT_URL ?: "https://github.com/shakilmunavary/terraform-infra-provision.git"
                    def repoName = repoUrl.tokenize('/').last().replace('.git', '')
                    def workDir = "/home/AI-SDP-PLATFORM/terra-analysis/${repoName}"

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
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
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
        }

        stage('Terraform Init & Plan') {
            steps {
                withEnv(["TF_WORK_DIR=${env.WORKDIR}"]) {
                    sh """
                        echo "📂 Moving to Terraform working directory: \$TF_WORK_DIR"
                        cd \$TF_WORK_DIR

                        echo "🔍 Running terraform fmt and validate"
                        cd terraform
                        terraform fmt -check
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
