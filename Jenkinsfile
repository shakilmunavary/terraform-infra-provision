@Library('aiLib') _

pipeline {
  agent any
  stages {
    stage('AI Compliance') {
      steps {
        script {
          aiPipeline(
            terraformRepo: "https://github.com/shakilmunavary/terraform-infra-provision.git",
            folderName: "terraform"
          )
        }
      }
    }
  }
}
