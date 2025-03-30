# Migrating

## From Ansible Docker Deploy project

If you want to migrate from Ansible Docker Deploy project, follow the following steps :

1. Follow the [Preparing the environment](../README.md#preparing-the-environment) section of the documentation.
1. Run this command: `./scripts/ansible-docker-deploy-to-values.sh /matrix ~/ess-config-values`.
This will create an initial values.yaml file with all your configuration from ansible-docker-deploy.
2. A difference with the Ansible Docker Deploy project is that Matrix Authentication Service is deployed under a dedicated hostname. Please define the required hostnames in  the generated `hostnames.yaml`.
2. Install PostgreSQL on your server
3. Create a new database for Synapse and Matrix Authentication Service. Follow the [Using a dedicated PostgreSQL database](./advanced.md#using-a-dedicated-postgresql-database) section of the advanced documentation.
4. Follow the [Certificates](../README.md#certificates) section of the documentation
5. Follow the [Installation](../README.md#installation) section of the documentation

The migration should now be completed.
