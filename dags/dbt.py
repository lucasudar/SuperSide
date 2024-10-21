from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.kubernetes_pod import KubernetesPodOperator
from datetime import datetime

# use a kube_config stored in s3 dags folder for now
kube_config_path = "/usr/local/airflow/dags/kube_config.yaml"

default_args = {
    'owner': 'superside',
    'retries': 0,
    "provide_context": True,
}

with DAG(
        dag_id='dbt',
        default_args=default_args,
        start_date=datetime(2024, 10, 16),
        schedule_interval=None,
        catchup=False) as dag:

    dbt_run_task = KubernetesPodOperator(
        task_id='dbt_run_task',
        name='dbt_run_task',
        namespace='mwaa',
        image='nikitastarkov/superside-dbt:latest-amd64',
        cmds=['dbt'],
        arguments=['run', '--profiles-dir', 'profiles'],
        is_delete_operator_pod=True,
        get_logs=True,
        config_file=kube_config_path,
        in_cluster=False,
        cluster_context="mwaa",
        resources={'request_cpu': '1', 'request_memory': '2Gi'},
    )

    dbt_test_task = KubernetesPodOperator(
        task_id='dbt_test_task',
        name='dbt_test_task',
        namespace='mwaa',
        image='nikitastarkov/superside-dbt:latest-amd64',
        cmds=['dbt'],
        arguments=['test', '--profiles-dir', 'profiles'],
        is_delete_operator_pod=True,
        get_logs=True,
        config_file=kube_config_path,
        in_cluster=False,
        cluster_context="mwaa",
        resources={'request_cpu': '1', 'request_memory': '2Gi'},
    )

    dbt_generate_docs_task = KubernetesPodOperator(
        task_id='dbt_generate_docs_task',
        name='dbt_generate_docs_task',
        namespace='mwaa',
        image='nikitastarkov/superside-dbt:latest-amd64',
        cmds=['dbt'],
        arguments=['docs', 'generate', '--profiles-dir', 'profiles'],
        is_delete_operator_pod=True,
        get_logs=True,
        config_file=kube_config_path,
        in_cluster=False,
        cluster_context="mwaa",
        resources={'request_cpu': '1', 'request_memory': '2Gi'},
    )

    dbt_run_task >> dbt_test_task >> dbt_generate_docs_task
