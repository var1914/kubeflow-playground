# Kubeflow POC: Simple ML Pipeline

## Prerequisites
- Docker installed
- Kubernetes cluster (minikube for local development)
- Python 3.7+
- kubectl configured

## Step 1: Setup Kubeflow (Local with Minikube)

```bash
# Start minikube
minikube start --memory=8192 --cpus=4

# Install Kubeflow Pipelines (lightweight version)
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=1.8.5"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic-pns?ref=1.8.5"

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=ml-pipeline --timeout=300s -n kubeflow

# Port forward to access UI
kubectl port-forward -n kubeflow svc/ml-pipeline-ui 8080:80
```

## Step 2: Install Required Python Packages

```bash
pip install kfp==1.8.22 pandas scikit-learn
```

## Step 3: Create Simple ML Pipeline Components

### Data Preparation Component

```python
# data_prep_component.py
from kfp.v2 import dsl
from kfp.v2.dsl import component, Input, Output, Dataset

@component(
    base_image="python:3.8",
    packages_to_install=["pandas", "scikit-learn"]
)
def prepare_data(dataset_output: Output[Dataset]):
    import pandas as pd
    from sklearn.datasets import load_iris
    from sklearn.model_selection import train_test_split
    
    # Load iris dataset
    iris = load_iris()
    df = pd.DataFrame(iris.data, columns=iris.feature_names)
    df['target'] = iris.target
    
    # Split data
    train_df, test_df = train_test_split(df, test_size=0.2, random_state=42)
    
    # Save datasets
    train_df.to_csv(f"{dataset_output.path}/train.csv", index=False)
    test_df.to_csv(f"{dataset_output.path}/test.csv", index=False)
    
    print(f"Training data shape: {train_df.shape}")
    print(f"Test data shape: {test_df.shape}")
```

### Model Training Component

```python
# train_component.py
@component(
    base_image="python:3.8",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def train_model(
    dataset_input: Input[Dataset],
    model_output: Output[Dataset],
    model_name: str = "random_forest"
):
    import pandas as pd
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.linear_model import LogisticRegression
    import joblib
    
    # Load training data
    train_df = pd.read_csv(f"{dataset_input.path}/train.csv")
    X_train = train_df.drop('target', axis=1)
    y_train = train_df['target']
    
    # Train model
    if model_name == "random_forest":
        model = RandomForestClassifier(n_estimators=100, random_state=42)
    else:
        model = LogisticRegression(random_state=42, max_iter=200)
    
    model.fit(X_train, y_train)
    
    # Save model
    joblib.dump(model, f"{model_output.path}/model.pkl")
    
    print(f"Model {model_name} trained successfully")
    print(f"Training accuracy: {model.score(X_train, y_train):.3f}")
```

### Model Evaluation Component

```python
# eval_component.py
@component(
    base_image="python:3.8",
    packages_to_install=["pandas", "scikit-learn", "joblib"]
)
def evaluate_model(
    dataset_input: Input[Dataset],
    model_input: Input[Dataset]
) -> float:
    import pandas as pd
    from sklearn.metrics import accuracy_score
    import joblib
    
    # Load test data and model
    test_df = pd.read_csv(f"{dataset_input.path}/test.csv")
    X_test = test_df.drop('target', axis=1)
    y_test = test_df['target']
    
    model = joblib.load(f"{model_input.path}/model.pkl")
    
    # Evaluate
    predictions = model.predict(X_test)
    accuracy = accuracy_score(y_test, predictions)
    
    print(f"Test accuracy: {accuracy:.3f}")
    return accuracy
```

## Step 4: Create the Pipeline

```python
# pipeline.py
from kfp.v2 import dsl

@dsl.pipeline(
    name="simple-ml-pipeline",
    description="A simple ML pipeline for iris classification"
)
def simple_ml_pipeline(model_type: str = "random_forest"):
    
    # Step 1: Prepare data
    data_prep_task = prepare_data()
    
    # Step 2: Train model
    train_task = train_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_name=model_type
    )
    
    # Step 3: Evaluate model
    eval_task = evaluate_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_input=train_task.outputs['model_output']
    )
    
    return eval_task.outputs
```

## Step 5: Compile and Run the Pipeline

```python
# run_pipeline.py
import kfp
from kfp.v2 import compiler

# Compile the pipeline
compiler.Compiler().compile(
    pipeline_func=simple_ml_pipeline,
    package_path='simple_ml_pipeline.yaml'
)

# Connect to Kubeflow Pipelines
client = kfp.Client(host='http://localhost:8080')

# Create experiment
experiment = client.create_experiment('simple-ml-experiment')

# Run pipeline
run = client.run_pipeline(
    experiment_id=experiment.id,
    job_name='simple-ml-run',
    pipeline_package_path='simple_ml_pipeline.yaml',
    params={'model_type': 'random_forest'}
)

print(f"Pipeline run started: {run.id}")
```

## Step 6: Complete Example Script

```python
# complete_example.py
import kfp
from kfp.v2 import dsl, compiler
from kfp.v2.dsl import component, Input, Output, Dataset

# All components defined above...
# (Include all the component definitions here)

# Pipeline definition
@dsl.pipeline(
    name="simple-ml-pipeline",
    description="A simple ML pipeline for iris classification"
)
def simple_ml_pipeline(model_type: str = "random_forest"):
    data_prep_task = prepare_data()
    train_task = train_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_name=model_type
    )
    eval_task = evaluate_model(
        dataset_input=data_prep_task.outputs['dataset_output'],
        model_input=train_task.outputs['model_output']
    )
    return eval_task.outputs

if __name__ == "__main__":
    # Compile pipeline
    compiler.Compiler().compile(
        pipeline_func=simple_ml_pipeline,
        package_path='simple_ml_pipeline.yaml'
    )
    
    # Run pipeline
    client = kfp.Client(host='http://localhost:8080')
    experiment = client.create_experiment('iris-classification')
    
    run = client.run_pipeline(
        experiment_id=experiment.id,
        job_name='iris-ml-pipeline-run',
        pipeline_package_path='simple_ml_pipeline.yaml',
        params={'model_type': 'random_forest'}
    )
    
    print(f"Pipeline submitted! Run ID: {run.id}")
    print("Visit http://localhost:8080 to see the pipeline execution")
```

## What This POC Demonstrates

### 1. **Component-Based Architecture**
Each step (data prep, training, evaluation) is a separate, reusable component that runs in its own container.

### 2. **Pipeline Orchestration**
Kubeflow automatically handles the execution order, data passing between components, and resource management.

### 3. **Reproducibility**
Every run is tracked with parameters, artifacts, and logs, making experiments reproducible.

### 4. **Scalability**
Components can be configured to use different resources (CPU, memory, GPU) based on needs.

## Running the POC

1. **Setup Environment**: Follow Step 1 to get Kubeflow running locally
2. **Create Pipeline**: Save the complete example as `iris_pipeline.py`
3. **Execute**: Run `python iris_pipeline.py`
4. **Monitor**: Open http://localhost:8080 to see your pipeline execution

## Expected Output

- Pipeline will create 3 pods (one for each component)
- Data preparation will generate train/test splits
- Model training will create a RandomForest classifier
- Evaluation will output test accuracy (~0.967 for iris dataset)
- All artifacts and logs will be stored and viewable in the UI

## Next Steps

Once this basic POC works, you can extend it by:
- Adding hyperparameter tuning
- Implementing model serving
- Adding data validation steps
- Creating more complex feature engineering
- Integrating with external data sources