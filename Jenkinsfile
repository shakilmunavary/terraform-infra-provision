pipeline {
    agent any

    stages {
        stage('Clone Terraform Repo') {
            steps {
                script {
                    // Extract repo name from Jenkins job context
                    def repoName = env.JOB_NAME.tokenize('/').last()
                    def repoUrl  = "https://github.com/your-org/${repoName}.git"
                    def workDir  = "/home/AI-SDP-PLATFORM/terra-analysis/${repoName}"

                    echo "📦 Cloning ${repoName} from ${repoUrl}"
                    sh """
                        rm -rf ${repoName}
                        git clone ${repoUrl}
                        mkdir -p ${workDir}
                        cp -r ${repoName}/* ${workDir}/
                    """

                    env.TF_WORKDIR = workDir
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                dir("${env.TF_WORKDIR}") {
                    sh """
                        terraform fmt -check
                        terraform validate
                        terraform init
                        terraform plan -out=tfplan.binary
                    """
                }
            }
        }
    }
}
