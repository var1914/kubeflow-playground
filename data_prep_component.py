# data_prep_component.py
from kfp import dsl
from kfp.dsl import component, Input, Output, Dataset

@component(
    base_image="python:3.10",
    packages_to_install=["pandas", "scikit-learn"]
)
def prepare_data(dataset_output: Output[Dataset]):
    import pandas as pd
    from sklearn.datasets import load_iris
    from sklearn.model_selection import train_test_split
    import os
    
    print(f"Dataset output path: {dataset_output.path}")
    
    # Load iris dataset
    iris = load_iris()
    df = pd.DataFrame(iris.data, columns=iris.feature_names)
    df['target'] = iris.target
    
    # Split data
    train_df, test_df = train_test_split(df, test_size=0.2, random_state=42)
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(dataset_output.path), exist_ok=True)
    
    # For Dataset artifacts, we need to create a directory structure
    dataset_dir = dataset_output.path
    if not dataset_dir.endswith('/'):
        os.makedirs(dataset_dir, exist_ok=True)
    else:
        os.makedirs(dataset_dir, exist_ok=True)
    
    # Save datasets
    train_path = f"{dataset_dir}/train.csv"
    test_path = f"{dataset_dir}/test.csv"
    
    train_df.to_csv(train_path, index=False)
    test_df.to_csv(test_path, index=False)
    
    print(f"Training data shape: {train_df.shape}")
    print(f"Test data shape: {test_df.shape}")
    print(f"Training data saved to: {train_path}")
    print(f"Test data saved to: {test_path}")
    
    # Create a metadata file to help with debugging
    with open(f"{dataset_dir}/metadata.txt", "w") as f:
        f.write(f"Training samples: {len(train_df)}\n")
        f.write(f"Test samples: {len(test_df)}\n")
        f.write(f"Features: {list(train_df.columns)}\n")