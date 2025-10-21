# Automated Docker Deployment Script 🚀

This robust shell script streamlines the deployment of Dockerized applications to a remote server. It automates repository cloning, Docker environment setup, file synchronization, application containerization, and Nginx reverse proxy configuration, ensuring a smooth and efficient deployment workflow for your projects.

## Installation

To get started with this deployment script, clone the repository and ensure the script is executable on your local machine.

```bash
git clone https://github.com/Uthmanduro/hng_13_devops_S2.git
cd hng_13_devops_S2
chmod +x deploy.sh
```

## Usage

The `deploy.sh` script is designed for interactive use, prompting you for all necessary deployment parameters.

1.  **Execute the script:**
    ```bash
    ./deploy.sh
    ```

2.  **Provide requested inputs:** The script will guide you through entering the following details:
    *   **Git Repository URL**: The `https` URL of your application's Git repository.
    *   **Personal Access Token (PAT)**: A Git Personal Access Token with repository read access. This token is used to authenticate with your Git provider.
    *   **Branch name**: The specific branch of your repository to deploy (e.g., `main`, `master`, `dev`). Defaults to `main` if left empty.
    *   **SSH Username**: The username for SSH connection on your target remote server.
    *   **Server IP Address**: The IP address or hostname of your remote deployment server.
    *   **SSH Key Path**: The local path to your private SSH key (e.g., `~/.ssh/id_rsa`) required for secure authentication with the server.
    *   **Application Port**: The internal port your Dockerized application listens on within its container (e.g., `8000` for a backend API, `3000` for a frontend).

    **Example Interactive Session:**
    ```
    Enter Git Repository URL: https://github.com/your-org/your-app.git
    Enter Personal Access Token (PAT): ghp_YOUR_PERSONAL_ACCESS_TOKEN
    Enter Branch name [default: main]: main
    Enter SSH Username: ubuntu
    Enter Server IP Address: 192.168.1.100
    Enter SSH Key Path: ~/.ssh/my_deploy_key
    Enter Application Port (internal container port): 80
    ```

3.  **Monitor Deployment Progress**: After providing the inputs, the script will perform the following actions:
    *   Cloning or updating your application repository locally.
    *   Checking for `Dockerfile` or `docker-compose.yml` to ensure Docker compatibility.
    *   Verifying SSH connectivity to the remote server.
    *   Installing or updating Docker, Docker Compose, and Nginx on the remote server.
    *   Transferring your project files to `/home/$SSH_USER/app` on the remote server using `rsync`.
    *   Building and running your Dockerized application using either `docker-compose` or `docker build` and `docker run`.
    *   Configuring Nginx as a reverse proxy on the remote server to direct web traffic on port 80 to your application's specified port.
    *   Performing final checks to validate the running Docker containers and Nginx configuration.

4.  **Optional Cleanup**: To remove the deployed application, its Docker containers, and Nginx configuration from the remote server, you can run the script with the `--cleanup` argument:
    ```bash
    ./deploy.sh --cleanup
    ```
    *Note: When running with `--cleanup`, you will still be prompted for all initial deployment variables as the script needs to establish SSH connection to the correct server. However, it will proceed directly to the cleanup phase.*

## Features

*   ✨ **Automated Repository Management**: Seamlessly clones a specified Git repository or pulls the latest updates if the repository already exists.
*   🐳 **Docker-centric Deployment**: Intelligently detects `Dockerfile` or `docker-compose.yml` to facilitate containerized application deployment.
*   🚀 **Remote Environment Provisioning**: Automates the installation and setup of essential tools like Docker, Docker Compose, and Nginx on the target server.
*   🔄 **Efficient File Synchronization**: Utilizes `rsync` for secure, incremental, and efficient transfer of project files to the remote server.
*   🌐 **Nginx Reverse Proxy Configuration**: Dynamically configures Nginx to act as a reverse proxy, serving the application on port 80 and routing requests to the appropriate container port.
*   🛡️ **Secure Access**: Employs SSH with key-based authentication for robust and secure remote command execution and file transfers.
*   ✅ **Deployment Validation**: Incorporates post-deployment checks to ensure Docker containers are running as expected and Nginx is correctly configured.
*   🧹 **Optional Cleanup Utility**: Provides a `--cleanup` flag for easy removal of deployed application artifacts and server configurations.
*   📄 **Comprehensive Logging**: Automatically logs all deployment actions and outputs to a dated log file for enhanced traceability and debugging.

## Technologies Used

| Technology         | Description                                                                  | Link                                                           |
| :----------------- | :--------------------------------------------------------------------------- | :------------------------------------------------------------- |
| **Bash**           | The powerful Unix shell and command language, forming the backbone of the script. | [Wikipedia](https://en.wikipedia.org/wiki/Bash_(Unix_shell))     |
| **Git**            | A distributed version control system crucial for managing source code.        | [Official Site](https://git-scm.com/)                          |
| **Docker**         | A platform for developing, shipping, and running applications in containers. | [Official Site](https://www.docker.com/)                       |
| **Docker Compose** | A tool for defining and running multi-container Docker applications.         | [Official Docs](https://docs.docker.com/compose/)              |
| **SSH**            | Secure Shell protocol, enabling secure remote access and command execution.  | [Wikipedia](https://en.wikipedia.org/wiki/Secure_Shell)        |
| **rsync**          | A versatile utility for fast, incremental file transfer across networks.      | [Wikipedia](https://en.wikipedia.org/wiki/Rsync)               |
| **Nginx**          | A high-performance HTTP and reverse proxy server, handling web traffic.      | [Official Site](https://nginx.org/)                            |

## Contributing

We welcome contributions to enhance the functionality and robustness of this deployment script! If you have suggestions for improvements, bug fixes, or new features, please follow these guidelines:

*   🍴 **Fork the repository** to your personal GitHub account.
*   🌳 **Create a new branch** for your feature or bug fix: `git checkout -b feature/your-feature-name`.
*   💻 **Implement your changes**, ensuring that your code is clean, well-commented, and thoroughly tested.
*   💬 **Write clear, concise, and descriptive commit messages** for your changes.
*   ⬆️ **Push your branch** to your forked repository.
*   🤝 **Open a Pull Request** to the `main` branch of this repository, providing a detailed description of your changes and their benefits.

## License

No explicit license file was found within the project directory. Please contact the author for specific licensing information regarding this project.

## Author Info

Connect with the creator of this project:

*   **Uthmanduro**
    *   LinkedIn: [https://linkedin.com/in/your_linkedin_username](https://linkedin.com/in/your_linkedin_username)
    *   Twitter: [https://twitter.com/your_twitter_handle](https://twitter.com/your_twitter_handle)

## Badges

![Shell Script](https://img.shields.io/badge/Language-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![Docker](https://img.shields.io/badge/Containerization-Docker-2496ED?logo=docker&logoColor=white)
![Docker Compose](https://img.shields.io/badge/Orchestration-Docker%20Compose-2496ED?logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Web%20Server-Nginx-009639?logo=nginx&logoColor=white)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)