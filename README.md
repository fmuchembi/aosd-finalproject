# R Shiny App with R Google Earth Engine (RGEE)

This is an R Shiny application that integrates with **Google Earth Engine (GEE)** using RGEE for data visualization and analysis. To use the application, you will need to follow a few steps to set up the environment and authenticate your Google account with GEE.

## Prerequisites

Before running the application, ensure you have the following:

- **R 4.4.3** or higher installed.
- **An active Google Earth Engine account** (sign up at https://signup.earthengine.google.com/).
- **Python** installed on your system (preferably via **Anaconda**).
- **RStudio** for running the R code.

## Steps to Run the Application

### 1. **Install Required Packages**

Start by installing the necessary R packages in your RStudio environment. Open a terminal or RStudio and run the following commands:

```r
# Install R packages
install.packages(c("rgee", "dplyr", "ggplot2", "lubridate", "stringr", "shiny", "shinydashboard", "leaflet", "sf", "geojsonio"))
```

### 2. **Create and Activate a Conda Environment**

Create a new **Conda environment** to manage your Python dependencies for Google Earth Engine.

- Open the **Anaconda Prompt** (or your terminal if Anaconda is installed).
- Run the following command to create a new environment named `gee`:

```bash
conda create -n gee python=3.8
```

- Activate the environment:

```bash
conda activate gee
```

- Install the **Google Earth Engine API** within the `gee` environment:

```bash
pip install earthengine-api==0.1.317
```

### 3. **Authenticate Google Earth Engine (GEE)**

- Inside RStudio, within the global.R File activate the Conda environment using **reticulate** and activate environment gee created:

```r
library(reticulate)
use_condaenv("gee")

# Load other required libraries
library(rgee)
library(dplyr)
library(ggplot2)
library(lubridate)
library(stringr)
library(shiny)
library(shinydashboard)
library(leaflet)
library(sf)
```

- Once the environment is active, run the **GEE initialization**:

```r
ee_Initialize()
```

- This will redirect you to a **Google login page**. Sign in with your Google Earth Engine account.
- After signing in, **copy the authorization token** provided.
- **Paste the token into the R console** when prompted to verify your authentication.

### 4. **Run the Application**

After successful authentication.
- The app will automatically start on [http://127.0.0.1:5167](http://127.0.0.1:5167). It may take upto 10 minutes to load.
- **Be patient** as the app initializes and starts loading the data.

### 5. **Interacting with the Application**

Once the application is loaded, you can freely interact with the map and  graphs.

---

## Troubleshooting

- **Error**: Ensure that you've successfully authenticated and copied the token into the R terminal.