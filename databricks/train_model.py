import mlflow, pandas as pd, numpy as np
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

n=5000
X = pd.DataFrame({'amount': np.random.exponential(scale=80, size=n), 'hour': np.random.randint(0,24,size=n)})
y = (X['amount']>120).astype(int)
X_train, X_test, y_train, y_test = train_test_split(X,y,test_size=0.2,random_state=42)

with mlflow.start_run():
  model = Pipeline([('scaler', StandardScaler()), ('clf', LogisticRegression(max_iter=200))])
  model.fit(X_train, y_train)
  mlflow.sklearn.log_model(model, "model", registered_model_name="fraud_model_ws")
