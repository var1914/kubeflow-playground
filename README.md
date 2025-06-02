# Kubeflow POC: Simple ML Pipeline

## Prerequisites
- Docker installed
- Kubernetes cluster (minikube for local development)
- Python 3.7+
- kubectl configured
- kustomise configured

## Step 1: Setup Kubeflow (Local with Minikube)

```bash
bash kubeflow_install.sh
```

## Step 2: Install Required Python Packages

```bash
pip install kfp pandas scikit-learn
```

## Step 3: Create Simple ML Pipeline Components

### Data Preparation Component: data_prep_component.py

### Model Training Component: train_component.py

### Model Evaluation Component: eval_component.py

## Step 4: Create the Pipeline: iris_pipeline.py


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
2. **Create Pipeline**: `iris_pipeline.py`
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