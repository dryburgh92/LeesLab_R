
## To install Packages-------------
instPak <- function(pkg){
  new.pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new.pkg)) 
    install.packages(new.pkg, dependencies = TRUE)
  sapply(pkg, require, character.only = TRUE)
}

#------------- Packages ----
packages <- c("readr","dplyr","shiny","data.table")
instPak (packages) 
#-----------------------------


## Duplicated value removal by SD ---------------
duplicateRemoverbySD <- function(x,startCol=1){
  matrix_data <- as.matrix(x[,-c(1:startCol)])
  sd <- apply(matrix_data,1,sd)
  order_num <- seq(1:nrow(x))
  transformed <- cbind(order_num,sd,x)
  name_list <- colnames(transformed)
  colnames(transformed) <- paste0("var_",seq(1:ncol(transformed)))
  colnames(transformed)[1:2] <- c("order_num","sd")
  colnames(transformed)[(startCol+2)] <- "grouped"
  res <- transformed %>% arrange(desc(sd)) %>% group_by(grouped) %>% filter(row_number()==1) %>% ungroup() %>% arrange(order_num)
  colnames(res) <- name_list
  return(res[c(-1,-2)])
}



options(shiny.maxRequestSize = 3000 * 1024 ^ 2)

# # # # #

server <- function(input, output, session) {
  datainFile <- reactive({
    inFile <- input$file1
    # Instead # if (is.null(inFile)) ... use "req"
    req(inFile)
    f <- fread(inFile$datapath,sep = input$sep) %>% as.data.frame()
    return(f)
  })
  doRem <- reactive({
    f <- datainFile()
    st <- which( colnames(f)== input$columnSelected)
    
    return(duplicateRemoverbySD(f,st))
  })
  
  select.column <- eventReactive(input$doSelectColumns, {
    
    f <- datainFile()
    vars <- colnames(f) %>% as.vector()
    # Update select input immediately after clicking on the action button. 
    updateSelectInput(session, "columnSelected","Select Columns", choices = vars)
    return(f)
   })
  
  doRemovalBySD <- eventReactive(input$doRemoval,{
    result.rm <- doRem()
    req(result.rm)
    print("Removal complete")
    
  })
  
  output$table_display <- renderTable({
    f <- select.column()
    f <- f[,input$columnSelected]  #subsetting takes place here
    head(f)
  })
  output$resultRemoval <- renderText({
    result.removal <- doRemovalBySD()
  })
  
  output$downloadData <- downloadHandler(
    filename = function() {
      paste("AfterRemoval_DuplicatedVal", '.txt', sep = '')
    },
    content = function(file) {
      
      contents.table <- doRem()
      write_delim(contents.table, file, delim = "\t")
    },
    contentType = "text/plain"
  )
  
}

ui <- fluidPage(titlePanel("Removal of duplicated values by standard deviation "),
                sidebarLayout(
                  sidebarPanel(
                    fileInput(
                      'file1',
                      'Choose txt File',
                      accept = c('text/csv',
                                 'text/comma-separated-values,text/plain',
                                 '.csv')
                    ),
                    radioButtons('sep', 'Separator',
                                 c(
                                   Comma = ',',
                                   Semicolon = ';',
                                   Tab = '\t'
                                 ),
                                 '\t'),
                    actionButton("doSelectColumns", "After upload file completion",class = "btn-primary"),
                    
                    selectInput("columnSelected", "Select Columns", choices = NULL),
                    
                    actionButton("doRemoval", "Do Removal", class = "btn-primary"),
                    br(),br(),
                    downloadButton('downloadData', 'Download Result')
                  ),
                  mainPanel(
                    tableOutput("table_display"),
                    textOutput("resultRemoval")
                  )
                ))

runApp(shinyApp(ui = ui, server = server),launch.browser = T)

