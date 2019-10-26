# Teste prática Work-at-Olist #
Como alternativa para resolver o desafio, apresento um data-warehouse com quatro dimensões, date, customers, products e sellers, utilizando o S3 da amazon para amazenamento temporário e o Redshift para persistência. A seguir é apresentado os detalhes.


## Data-warehouse ##
<p>
Durante a modelagem de dados pensei numa estrutura dimensional com quatro dimensões d_date, d_customers, d_products, d_sellers e uma tabela fato f_sales, o seu diagrama relacional ficou assim:
</p>
![](https://workolistexample.s3.amazonaws.com/data-set/olist+data-warehouse.png)

<p>
Nas dimensões d\_sellers, d\_product e d\_customers adicionei os campos date\_from, date\_until e version, os dois primeiros campos date\_from e date\_until são campos no formato data, esses campos informam até quando o registro está valido, digamos que o produto mudou de peso ou sofreu alguma alteração de tamanho, o campo version informa a versão do item, ela é útil para buscar a versão mais recente do item.
<p/>
<p>
Na dimensão d_date foi adicionado algumas decomposições de data como dia da semana, mes, semestres, trimestre entre outros, que pode ser útil para analisar a performance das vendas no tempo, alem disso, foi adicionado o campos name_holiday e o type_holiday, esses campos são úteis para saber a performance das vendas nos feriados. 
Logo em seguida é apresentado os aspectos de arquitetura.
</p>

## Arquitetura proposta ##
<p>
Na arquitetura foi utilizado o pentaho data integration, Amazon S3 e Amazon Redshift. Foi escolhido esse conjunto primeiramente pelo pentaho data integration, possuir alta conectividade e integração com os serviços da amazon, o conjunto amazon S3 e amazon Redshift por possuir a arquitetura de processamento paralelo em massa para carregar os dados do S3 para redshift, essa função pode ser amplamente explorada, fatiando arquivos grandes para tamanhos menores, em seguida é apresentado os detalhes de construção.
</p>
![](https://workolistexample.s3.amazonaws.com/data-set/olist+arquitetura.png)

<p>Basicamente a elaboração da estrutura segue os seguintes passos:</p>
1. Criar o bucket S3 e o cluster Redshift.
2. Criar o esquema do banco no redshift.
3. Transformar os arquivo, carregar no S3 e copiar para o Redshift

### Criar bucket S3 E Cluster Redshift ###
<p>Foi configurado as credenciais AMI para poder utilizar a AWS command Line remotamento, e os demais requisitos como a sua própria instalação e um cliente para o banco postgres, como tudo configurado, foi executado o seguinte script para criar o bucket S3 chamado workolistexample e o cluster redshift com dois nós 
dc2.large.
</p>

    
    #!/bin/bash -e
	#aws s3 mb s3://workolistexample

	#create cluster with paramets passed from enviroment variable
	aws redshift create-cluster --cluster-identifier $cluster_name --node-type ds2.large --number-of-nodes 2 --db-name $redshift_dbname --master-username $redshift_username --master-user-password $redshift_password


	#print mensage to screen
	echo "Waiting for redshift endpoint"

	#Waiting for the cluster to stay available
	aws redshift wait cluster-available --cluster-indentifier $cluster_name

	#get the endpoint to connect and create datawarehouse
	endpoint=$(aws redshift describe-clusters --cluster-identifier $cluster_name --query "Clusters[*].Endpoint.Address" --output text)
	port=$(aws redshift describe-clusters --cluster-identifier $cluster_name --query "Clusters[*].Endpoint.Port" --output text)`



### Criar o esquema do banco no redshift. ###
<p>
Com o endpoint do banco retornado e armazenado na variável de ambiente endpoint, é feito a conexão com o banco utilizando o psql:
</p>
	`#connect to just cluster created 
	psql --host=$endpoint --port=$port --username=$redshift_username --dbname=$redshift_dbname -f model.sql

	psql -f model.sql`	
<p>
E em seguida carregado o modelo abaixo:
</p>
	    `create table if not exists 
    	public.d_date(
    		date_sk BIGINT IDENTITY(0,1) PRIMARY KEY,
    		field_date TIMESTAMP,
    		year SMALLINT,
    		month SMALLINT,
    		day_of_year SMALLINT,
    		day_of_mouth SMALLINT,
    		day_of_week SMALLINT,
    		week_of_year SMALLINT,
    		day_of_week_desc VARCHAR(30),	
    		day_of_week_desc_short VARCHAR(30),
    		month_desc VARCHAR(30),
    		month_desc_short VARCHAR(3),
    		quarter VARCHAR(1),
    		half VARCHAR(1),
    		name_holiday VARCHAR(200),
    		type_holiday VARCHAR(50)
    	);
    	create table if not exists
    	public.d_customers(
    		customer_id VARCHAR(100) PRIMARY KEY,
    		city VARCHAR(35),
    		state VARCHAR(2),
    		latitude DOUBLE PRECISION,
    		longitude DOUBLE PRECISION,
    		version BIGINT DEFAULT NULL,
    		date_from TIMESTAMP DEFAULT NULL,
    		date_until TIMESTAMP DEFAULT NULL
    	);
    	
    	CREATE TABLE IF NOT EXISTS 
    	public.d_sellers(
    		seller_id VARCHAR(100) PRIMARY KEY, 
    		city VARCHAR(35),
    		state VARCHAR(2),
    		latitude DOUBLE PRECISION,
    		longitude DOUBLE PRECISION,
    		version BIGINT DEFAULT NULL,
    		date_from TIMESTAMP DEFAULT NULL,
    		date_until TIMESTAMP DEFAULT NULL
    	);
    	CREATE TABLE IF NOT EXISTS 
    	public.d_products(
    		product_id VARCHAR(100) PRIMARY KEY, 
    		category_name  VARCHAR(100),
    		weight_g  DOUBLE PRECISION,
    		length_cm DOUBLE PRECISION,
    		height_cm DOUBLE PRECISION,
    		width_cm DOUBLE PRECISION,
    		version BIGINT DEFAULT NULL,
    		date_from TIMESTAMP DEFAULT NULL,
    		date_until TIMESTAMP DEFAULT NULL
    	);
    	CREATE TABLE IF NOT EXISTS 
    	public.f_sales(
    		order_id VARCHAR(42) NOT NULL,
    		product_sk VARCHAR(100) REFERENCES d_products(product_id),
    		sellers_sk VARCHAR(100) REFERENCES d_sellers(seller_id),
    		customer_sk VARCHAR(100) REFERENCES d_customers(customer_id),
    		purchase_date_sk BIGINT REFERENCES d_date(date_sk),
    		shipping_limit TIMESTAMP,
    		status VARCHAR(50),
    		freight_value DOUBLE PRECISION,
    		price DOUBLE PRECISION,
    		payment_type VARCHAR(50),
    		payment_value DOUBLE PRECISION,
    		payment_installments DOUBLE PRECISION	
    	)
    	compound sortkey(order_id, product_sk, sellers_sk);


### Transformar os arquivos, carregar no S3 e copiar para o Redshift ###
<p>Nessa fase foi utilizado o pentaho data integration executando os dez passos da figura abaixo, os passos 1, 3, 5, 7 e 9 leem os arquivos csv's, fazem agregação e salvam no S3. Os outros passos basicamente escrevem no redshift usando o comando copy.</p>

![](https://workolistexample.s3.amazonaws.com/data-set/work-flow.png)
#### Carregar d_date ####
<p>Primeiramente, é criado a dimensão data no passo 1, com o seguinte fluxo. Na área 1 a data é decomposta  e na área 2 é feita a busca por feriados no site http://www.calendario.com.br/, após isso é cruzado a data do feriado feito na área 1 com os dados provenientes do site<p/>  
![](https://workolistexample.s3.amazonaws.com/data-set/d_data.png)


<p>Depois que os arquivos da dimensão data já terem sido escritos no S3, o passo 2 da figura do fluxo principal, conecta ao redshift e executa o comando copy, referenciado o arquivo do s3 e a tabela de destino d_date.</p>

![](https://workolistexample.s3.amazonaws.com/data-set/copy_d_data+redfshift.PNG)

<p>Abaixo é ilustrado o comando para carregar os dados no redshift.</p>
	copy public.d_date
	(
		field_date,
		year,
		month,
		day_of_year,
		day_of_mouth,
		day_of_week,
		week_of_year,
		day_of_week_desc,
		day_of_week_desc_short,
		month_desc,
		month_desc_short,
		quarter,
		half,
		name_holiday,
		type_holiday
	) 
	from 's3://workolistexample/data-set/d_data.csv'
	delimiter ','
	csv
	ignoreheader 1`    


<p>
Os passos seguintes do fluxo tem a mesa estrutura leêm o csv, salvam no S3 e copiam para o Redshift.
</p>
#### Carregar d_customer ####
<p>Para carregar a dimensão customers foi criado o seguinte fluxo, é lido os arquivo csv olist_customers_dataset e geolocation_zip_code_prefix logo é seguida são unidos e então é saldo para o s3.
</p>
![](https://workolistexample.s3.amazonaws.com/data-set/d_customer.PNG)
#### Carregar d_sellers ####
O carregamento da dimensão sellers é parecido com a da customers
![](https://workolistexample.s3.amazonaws.com/data-set/d_sellers.PNG)
#### Carregar d_products ####
<p>
A carga dimensão d_products é a mais simples de todas, basta ler os dados dos aquivos e enviar para o s3.</p>
![](https://workolistexample.s3.amazonaws.com/data-set/d_product.PNG)
#### Carregar f_salles ####
<p>Por fim é carregado a tabela f_salles, é carregado os arquivos olist_order_items_dataset, olist_order_dataset, olist_order_payments_dataset em seguida é agregado as três planilhas em uma só, logo em seguida é escrita no S3. </p>

![](https://workolistexample.s3.amazonaws.com/data-set/f_sallers.PNG)
<p>Como todos os passos concluídos o banco já está criado e pronto para uso.</p>

