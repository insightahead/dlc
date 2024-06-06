# Purpose of the Data Learning CLI

The Data Learning CLI is a tool designed to help data practitioners and learners with their learning journey.
It is a tool to generate synthetic data that mimics the key activities of a business selling online courses.
Unlike many existing datasets, which often have fixed distributions across multiple axes or columns, this app allows users to create data with diverse shapes and variances.

## Key Objectives

- **Data Generation:** Provide users with the ability to generate synthetic data that reflects the complexities of real-world business scenarios, including various anomalies and outliers.
- **Customizable Distributions:** Enable users to specify custom distributions and relationships within the data, allowing for the creation of datasets that are tailored to specific analytical needs.

## Practical Applications

- **Simulation of Business Operations:** Users can simulate various business activities such as user signups, sales over time, and promotional campaigns.
- **Anomaly Detection:** Generate data with intentional anomalies to practice and enhance skills in anomaly detection and handling.

## Installation

### Prerequisites

Before installing the app, ensure you have the following:

1. **Docker:** Make sure Docker is installed and running on your machine. You can download it from [Docker's official website](https://www.docker.com/).
2. **Docker Compose:** Ensure Docker Compose is installed. Instructions for installation can be found on the [Docker Compose installation page](https://docs.docker.com/compose/install/).
3. **Git:** Install Git to check out the repository. You can download it from [Git's official website](https://git-scm.com/).
4. **Operating System Compatibility:** The app should be compatible with your operating system. Ensure you can run Docker and Docker Compose on your OS.
5. **Internet Connection:** A stable internet connection is required to download dependencies and the repository.

Once you have these prerequisites in place, you can proceed with the installation steps.

### Installation Steps

The application is composed of multiple services that run as Docker Compose services. Follow the steps below to install and start the application:

1. **Check out the repository:**

   ```bash
   git clone https://github.com/insightahead/dlc.git
   cd <repository-directory>
   ```

2. **Run the startup script:**
   - **For Linux, macOS, or Windows WSL2:**

     ```bash
     ./run-dlc.sh
     ```

   - **For Windows (PowerShell):**

     ```powershell
     ./run-dlc.ps1
     ```

3. **Verify the services:**
   - If the output of the script shows no errors, all services have started successfully.
   - Navigate to [http://localhost:5500/](http://localhost:5500/) to access the app UI.

4. **Troubleshooting:**
   - If you encounter any issues during startup, go to Docker Desktop and check the logs of the failing service.
   - If the issue persists, open an issue in the repository with the relevant details.

By following these steps, you should be able to install and run the companion app smoothly.
