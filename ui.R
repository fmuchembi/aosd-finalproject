library(shiny)
library(shinydashboard)
library(leaflet)
library(jsonlite)
library(geojsonsf)
library(htmlwidgets)

ui <- dashboardPage(
  dashboardHeader(title = "Land Restoration Monitoring Dashboard", titleWidth = 300),
  
  dashboardSidebar(
    tags$div(id = "loading-content",
             tags$img(src = "spinner.gif", id = "loading-spinner", style = "display: none;"),
             tags$span("Loading data...", id = "loading-message", style = "display: none;")
    ),
    
    selectInput("selected_name", "Select Area", choices = NULL),
    
    radioButtons("selected_season", "Season:", 
                 choices = c("Short Rains" = "short_rains", 
                             "Long Rains" = "long_rains", 
                             "After Long Rains" = "after_long_rains"),
                 selected = "short_rains")
  ),
  
  dashboardBody(
    tags$head(
      tags$style(HTML("
        .content-wrapper {
          background-color: white;
        }
        
        .skin-blue .main-sidebar {
          background-color: white;
        }
        
        .skin-blue .main-sidebar .sidebar {
          color: black;
        }
        
        .skin-blue .main-header .navbar {
          background-color: #086A87;
          color: black;
        }
        
        .box {
          box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
          transition: all 0.3s cubic-bezier(.25,.8,.25,1);
          background-color: white;
          border-top: 1px solid #ddd;
        }
        
        .box:hover {
          box-shadow: 0 14px 28px rgba(0,0,0,0.25), 0 10px 10px rgba(0,0,0,0.22);
        }
        
        .box-title {
          color: black;
        }
        
        .control-label {
          font-weight: bold;
          color: black;
        }
        
        .btn-primary {
          background-color: white;
          border-color: #ddd;
          color: black;
        }
        
        .btn-primary:hover {
          background-color: #f5f5f5;
          border-color: #ccc;
        }
      "))
    ),
    
    fluidRow(
      column(width = 12,
             box(width = NULL, solidHeader = TRUE, status = "primary",
                 title = "Project Map",
                 leafletOutput("project_map", height = "400px")
             )
      )
    ),
    
    fluidRow(
      column(width = 6,
             box(width = NULL, solidHeader = TRUE, status = "primary",
                 title = "NPP Analysis",
                 plotOutput("npp_plot", height = "350px")
             )
      ),
      column(width = 6,
             box(width = NULL, solidHeader = TRUE, status = "primary",
                 title = "LST Analysis",
                 plotOutput("lst_plot", height = "350px")
             )
      )
    ),
    
    fluidRow(
      column(width = 12,
             box(width = NULL, 
                 title = "About This Dashboard",
                 status = "primary",
                 collapsible = TRUE,
                 collapsed = TRUE,
                 p("This dashboard visualizes NPP (Net Primary Productivity) and LST (Land Surface Temperature) 
                   data for various regions."),
                 p("The dashboard also shows the areas that restoration efforts can be expanded to."),
             )
      )
    )
  )
)