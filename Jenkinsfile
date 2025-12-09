@Library(value = 'jenkins-shared-ai-lib@main', changelog = false) _


pipeline {
  agent any
  stages {
    stage('AI Compliance') {
      steps {
        script {
          aiAnalytics(
            terraformRepo: "https://github.com/shakilmunavary/terraform-infra-provision.git",
            folderName: "terraform"
          )
        }
      }
    }
  }
}
