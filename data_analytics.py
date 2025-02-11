import pandas as pd
import numpy as np

# 1. Read the data.csv file
df = pd.read_csv('data.csv')

# Remove '%' and convert to float
df = df.replace('%', '', regex=True).astype(float) / 100

# 2. Calculate the correlation matrix
correlation_matrix = df.corr()

# Round the correlation matrix to 2 decimal places
correlation_matrix = correlation_matrix.round(2)

# 3. Mask the upper triangle of the correlation matrix
mask = np.tril(np.ones_like(correlation_matrix, dtype=bool))
lower_triangle = correlation_matrix.where(mask)

# 4. Export the lower triangle of the correlation matrix to result.csv
lower_triangle.to_csv('result.csv')
