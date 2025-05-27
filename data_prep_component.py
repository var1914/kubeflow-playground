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
    
    # Ensure the output directory exists
    import os
    os.makedirs(dataset_output.path, exist_ok=True)
    
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