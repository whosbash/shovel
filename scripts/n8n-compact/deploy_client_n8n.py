from jinja2 import Environment, FileSystemLoader
import subprocess
import socket

from dotenv import load_dotenv
import logging
import os


logging.basicConfig(level=logging.INFO)


def create_base_nginx_config(nginx_config_path, server_name):
    """
    Creates the base Nginx configuration file if it doesn't exist.
    """
    base_nginx_config = f"""
server {{
 server_name {server_name};

 listen 443 ssl;
 ssl_certificate /etc/letsencrypt/live/conexxohub.com.br/fullchain.pem;
 ssl_certificate_key /etc/letsencrypt/live/conexxohub.com.br/privkey.pem;
 include /etc/letsencrypt/options-ssl-nginx.conf;
 ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
}}

server {{
 listen 80;
 server_name {server_name};
 return 301 https://$host$request_uri;
}}
"""

    
    if not os.path.exists(nginx_config_path):
        try:
            # Create the Nginx configuration file
            with open(nginx_config_path, 'w') as f:
                f.write(base_nginx_config)
            
            print(f"Base Nginx configuration file created at {nginx_config_path}")

            # Set appropriate permissions for the Nginx configuration file
            subprocess.run(['chown', 'root:root', nginx_config_path], check=True)
            subprocess.run(['chmod', '644', nginx_config_path], check=True)
        except Exception as e:
            print(f"Error creating Nginx configuration file: {e}")
            raise
    else:
        print(f"Nginx configuration file already exists at {nginx_config_path}")


def find_next_available_port(base_port, max_attempts=100):
    """
    Finds the next available port, starting from base_port, and checks up to max_attempts ports.
    """
    attempts = 0
    while attempts < max_attempts:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.bind(("localhost", base_port))
            sock.close()
            return base_port
        except OSError:
            base_port += 1
            attempts += 1
    raise Exception(f"No available port found after {max_attempts} attempts.")


def generate_docker_compose(client_data: dict):
    """
    Generates a docker-compose file from a Jinja2 template.
    """
    try:
        env = Environment(loader=FileSystemLoader(searchpath=os.getcwd()))
        template = env.get_template('docker-compose.yaml.j2')
        if not template:
            raise FileNotFoundError("The Jinja2 template for docker-compose was not found.")


        try:
            rendered_yaml = template.render(client_data)
        except Exception as e:
            logging.error(f"Error rendering template: {e}")
            raise

        docker_compose_file = f'docker-compose-{client_data["client_identifier"]}.yaml'

        with open(docker_compose_file, 'w') as f:
            f.write(rendered_yaml)

        print(f"{docker_compose_file} has been generated successfully!")
        return docker_compose_file
    except Exception as e:
        print(f"Error generating docker-compose file: {e}")
        raise


def run_docker_compose(docker_compose_file):
    """
    Runs the Docker container using the generated docker-compose file.
    """
    try:
        command_list=['docker-compose', '-f', docker_compose_file, 'up', '-d']
        subprocess.run(command_list, stderr=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Error running Docker: {e.stderr.decode('utf-8')}")


def update_nginx_config(nginx_config_path, client_data):
    """
    Updates the Nginx configuration file to add a new location block for the client.
    If the file doesn't exist, it creates one.
    """
    client_identifier = client_data['client_identifier']
    client_port = client_data['client_port']

    new_location_block = f"""
# Proxy {client_identifier} service
location /n8n/{client_identifier}/ {{
    proxy_pass http://localhost:{client_port}/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host $host;
    proxy_cache_bypass $http_upgrade;
    rewrite ^/n8n/{client_identifier}(/.*)$ $1 break;
}}
"""

    if not os.path.exists(nginx_config_path):
        print(f"Nginx config file {nginx_config_path} does not exist. Creating a new one.")
        with open(nginx_config_path, 'w') as f:
            f.write("# Nginx configuration for n8n clients\n")

    with open(nginx_config_path, 'r+') as f:
        nginx_config = f.read()

        if new_location_block not in nginx_config:
            f.write(new_location_block)
            print(f"Added {client_identifier} location to Nginx config.")
        else:
            print(f"{client_identifier} location already exists in Nginx config.")


def reload_nginx():
    try:
        subprocess.run(['nginx', '-t'], check=True)  # Test config
        subprocess.run(['nginx', '-s', 'reload'], stderr=subprocess.PIPE, check=True)
        logging.info("Nginx configuration reloaded.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error reloading Nginx: {e.stderr.decode()}")
        raise




def enable_nginx_site(nginx_enabled_sites_basepath, nginx_config_path):
    """
    Creates a symbolic link in /etc/nginx/sites-enabled to enable the site.
    """
    sites_enabled_path = os.path.join('/etc/nginx/sites-enabled', os.path.basename(nginx_config_path))
    if not os.path.exists(sites_enabled_path):
        try:
            subprocess.run(['ln', '-s', nginx_config_path, sites_enabled_path], check=True)
            print(f"Site enabled: {sites_enabled_path}")
        except Exception as e:
            print(f"Error enabling site: {e}")
            raise
    else:
        print(f"Site already enabled: {sites_enabled_path}")



def main():
    load_dotenv()
    base_port = 5678
    client_port = find_next_available_port(base_port)

    client_data = {
        'postgres_host': os.getenv('DB_POSTGRESDB_HOST'),
        'postgres_port': os.getenv('DB_POSTGRESDB_PORT'),
        'postgres_user': os.getenv('DB_POSTGRESDB_USER'),
        'postgres_password': os.getenv('DB_POSTGRESDB_PASSWORD'),
        'client_identifier': 'client_identifier',
        'basic_auth_user': 'client_identifier',
        'basic_auth_password': 'supersecurepassword',
        'client_port': client_port
    }

    try:
        docker_compose_file = generate_docker_compose(client_data)
        run_docker_compose(docker_compose_file)
        update_nginx_config(nginx_available_sites_basepath, client_data)
        reload_nginx()
        enable_nginx_site(nginx_enabled_sites_basepath, nginx_available_config_path)
    except Exception as e:
        logging.error(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
