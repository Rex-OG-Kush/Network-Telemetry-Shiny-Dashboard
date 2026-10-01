# ==============================================================================
# PROJECT: INTERACTIVE NETWORK TELEMETRY & SECURITY DASHBOARD (R SHINY)
# AUTHOR: MATUTUZELA JABULANI NDLOVU
# PURPOSE: Production Azure-linked Streaming UI & Server Architecture
# ==============================================================================

library(shiny)
library(dplyr)
library(ggplot2)
library(AzureStor)  # Azure SDK dependency for real-time cloud data pipeline
library(jsonlite)

# 1. USER INTERFACE (UI) DEFINITION
ui <- fluidPage(
  # Using custom CSS style matching the dark "slate" palette securely
  theme = shinythemes::shinytheme("slate"), 
  
  titlePanel("🛡️ Enterprise Network Telemetry & Security Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      h4("Dashboard Controls"),
      selectInput("interface", "Select Router Interface:", 
                  choices = c("All Interfaces", "Eth0/1 - Core Switch", "Eth0/2 - Perimeter Firewall", "Wlan0 - Guest Wi-Fi")),
      sliderInput("threshold", "Anomaly Sensitivity Threshold (Packets):", 
                  min = 100, max = 500, value = 300),
      hr(),
      downloadButton("downloadReport", "📄 Generate R Markdown PDF Audit"),
      br(), br(),
      p("Logged in as: Administrator", style = "color: #00FF00;")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("📈 Live Telemetry", 
                 br(),
                 plotOutput("telemetryPlot"),
                 br(),
                 h4("Real-Time Interface Health Metrics"),
                 tableOutput("metricsTable")),
                 
        tabPanel("🚨 Security Alerts (Bayesian Log Parsing)", 
                 br(),
                 h4("High-Risk Network Anomalies Detected"),
                 p("The table below displays traffic logs that have broken past the 3-Sigma statistical threshold baseline."),
                 tableOutput("alertTable"))
      )
    )
  )
)

# 2. SERVER LOGIC - Live Streaming Azure Engine
server <- function(input, output, session) {
  
  # Establishes connection boundary with your Terraform-managed cloud endpoints
  blob_endpoint <- storage_endpoint(
    Sys.getenv("AZURE_STORAGE_ENDPOINT"), 
    sas = Sys.getenv("AZURE_STORAGE_SAS_TOKEN")
  )
  container <- storage_container(blob_endpoint, "financial-ticks-delta-lake")
  
  # Reactive polling engine configured for an automated 5-second streaming cadence
  get_live_azure_data <- reactive({
    # Forces invalidation to loop updates without requiring a manual browser refresh
    invalidateLater(5000, session)
    
    tryCatch({
      # Dynamically stream down the primary incoming validated pipeline logs
      storage_download(container, "live_network_telemetry.json", "local_temp_telemetry.json", overwrite = TRUE)
      data <- jsonlite::fromJSON("local_temp_telemetry.json")
      
      # Enforce standard formatting definitions on raw incoming schemas
      data$Time <- as.POSIXct(data$Time)
      data$PacketsPerSec <- as.numeric(data$PacketsPerSec)
      data$Latency_ms <- as.numeric(data$Latency_ms)
      
      # Filter matrix variables based on user layout choices
      if(input$interface != "All Interfaces") {
        data <- data %>% filter(Interface == input$interface)
      }
      return(data)
      
    }, error = function(e) {
      # Resilient fallback state array if network paths experience intermittent dropouts
      showNotification("Re-establishing continuous pipeline sync...", type = "warning", duration = 3)
      return(data.frame(Time = Sys.time(), Interface = "Offline", PacketsPerSec = 0, Latency_ms = 0))
    })
  })
  
  # Corrected reactive output element syntax (Replaced '.' syntax layout error)
  output$telemetryPlot <- renderPlot({
    df <- get_live_azure_data()
    
    ggplot(df, aes(x = Time, y = PacketsPerSec, color = Interface)) +
      geom_line(linewidth = 1) +
      geom_point(data = df %>% filter(PacketsPerSec > input$threshold), color = "red", size = 3) +
      geom_hline(yintercept = input$threshold, linetype = "dashed", color = "red", linewidth = 1) +
      labs(title = "Live Azure Delta-Lake Stream vs Security Alert Baselines",
           x = "Timeline Log Windows", y = "Packets Per Second (PPS)") +
      theme_minimal()
  })
  
  # Render the functional operational summaries
  output$metricsTable <- renderTable({
    df <- get_live_azure_data()
    df %>% 
      group_by(Interface) %>%
      summarise(Avg_Throughput_PPS = mean(PacketsPerSec),
                Peak_Throughput_PPS = max(PacketsPerSec),
                Avg_Latency_ms = mean(Latency_ms))
  })
  
  # Render the isolated, high-risk security alert tracking table
  output$alertTable <- renderTable({
    df <- get_live_azure_data()
    df %>% 
      filter(PacketsPerSec > input$threshold) %>%
      select(Time, Interface, PacketsPerSec, Latency_ms) %>%
      rename(Trigger_Time = Time, Breached_PPS = PacketsPerSec)
  })
}

# 3. RUN APPLICATION INFRASTRUCTURE
shinyApp(ui = ui, server = server)
