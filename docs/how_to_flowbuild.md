
# Flowbuild engine: 

A documentação oficial da engine [1] FlowBuild encontra-se em https://flow-build.github.io/ . Este arquivo não pretende substituir o original, mas a servir o usuário que esteja na lida diária de uso do workflow. Portanto, ele sumariza, de forma unificada, as informações necessárias para utilizá-lo. 

- OS utilizado: Linux

- Instruções a usuários Windows: acompanhar passos abaixo e adaptar através de ferramentas _Postman_ ou _Insomnia_ (URL: https://flow-build.github.io/docs/documentation/instalacao)

## Recomendação inicial:

Os ```curl```s desta seção, quando realizados no terminal, vem em formato *.json sem indentação e breakline no final. 
	O autor deste tutorial recomenda copiar estes valores json e usar a ferramenta disponível no URL a seguir para formatá-los: https://jsonformatter.org/

## Configuração:

As instruções a seguir

1) Clonar https://github.com/flow-build/workflow-api em ```$WORKFLOW_PATH```;
2) Navegue até o diretório $WORKFLOW_PATH e suba o servidor: 

	```sudo docker-compose up```

3) Gerar token com comando abaixo por (terminal || Postman || Insomnia) ou URL jwt.io. Os campos ```{{minha-nova-senha}}``` e ```{{duração}}``` são opcionais e à escolha do usuário: 

	```curl --location --request POST "{{meu host}}/token" --header 'x-secret: {{minha-nova-senha}}' --header 'x-duration: {{duração}}' --header 'Content-Type: application/json'```
	
**Lembre-se:** A senha 'x-secret' padrão  é 1234 e a duração de expiração 'x-duration' padrão 60000 [s], i.e. 1 hora. O autor deste tutorial recomenda utilizar 1 dia (1440000 = [24 h]*[60 min]*[1000 ms]) para realizar este tutorial.

**Tome nota**: O cliente (quem faz a requisição) sabe sobre o uso da chave JWT pelo servidor. Desta forma, não é necessario e suficiente o uso do comando acima. Ou seja, qualquer chave que siga as regras JWT é válido, e.g. gerado pelo URL jwt.io ;

**Lembre-se:** Você deve usar a chave gerada a partir daqui no lugar de {{meu token}};

4) Substituir chave do ```JWT_KEY``` em .env.docker pelo token do passo anterior

## Como usar:

Caso queira testar com uma blueprint válida, utilize o exemplo ```simple_bp.json``` presente neste diretório. Abaixo encontram-se as opções possíveis para utilização da *engine* Flowbuild. As chamadas ```curl``` podem ser executadas no terminal. 

Os campos ```{{meu host}}```, ```{{meu token}}``` e ```{{minha senha}}``` são respectivamente: 

- o link do servidor;
- Um token válido (Se ele expirou, siga os passos da sessão "Configuração" a partir do item 3))
- Senha cadastrada na sessão "Configuração", item 3)

**Tome nota**: Substituir o trecho ```{{meu host}}``` por ```localhost:3000```.

Abaixo, as opões enumeradas correpondem a entidades e suas ações de gerenciamento da _engine_:

1) Blueprints cadastradas:
+ Listar:

	**Requisição	:** GET /workflows
	**Comando		:**  ``curl --location --request GET "{{meu host}}/workflows" --header "Authorization: Bearer {{meu token}}" --header "x-secret={{minha senha}}"``

+ Criar/Atualizar:

	**Requisição	:** POST /workflows
	**Comando		:**  ```curl --location --request POST "{{meu host}}/workflows" --header 'content: application/json' --header 'Content-Type: application/json' --header "Authorization: Bearer {{meu token}}" --data-raw "$3"```
	
+ Consultar por:
	- ```{{id da BP}}```:
	
		**Requisição	:** GET /workflows/{{id da BP}}
		**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/{{id da BP}}" --header "Authorization: Bearer {{meu token}}" --header "x-secret={{minha-nova-senha}}"```

	- ```{{nome da BP}}```:

		**Requisição	:** ```GET /workflows/name/{{nome da BP}}```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/name/{{nome da BP}}" --header "Authorization: Bearer {{meu token}}" --header "x-secret={{minha-nova-senha}}"```

2) Processos cadastrados:

+ Listar
		**Requisição	:** ```GET "{{meu host}}/processes"```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/processes" --header "Authorization: Bearer {{meu token}}"```

+ Criar: 
	
	**Requisição	:** ```GET /workflows/{workflow_id}/processes```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/{{workflow_id}}/processes" --header "Authorization: Bearer {{meu token}}"```

+ Iniciar:
	+ Chave ```{{id do workflow}}```
		
		**Requisição	:** ```GET /workflows/{workflow_id}/processes```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/{{workflow_id}}/processes" --header "Authorization: Bearer {{meu token}}"```

	+ Chave ```{{nome do workflow}}```
	
		**Requisição	:** ```/workflows/name/{workflow_name}/start```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/name/{{nome do workflow}}/start" --header "Authorization: Bearer {{meu token}}"```

+ Ler: 

	**Requisição	:** ```GET /workflows/{{id do workflow}}/processes```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/workflows/{{id do workflow}}/processes" --header "Authorization: Bearer {{meu token}}"```

+ Acompanhar:

	**Requisição	:** ```GET /processes/{{id do processo}}```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}" --header "Authorization: Bearer {{meu token}}"```

+ Consultar histórico:

	**Requisição	:** ```GET /processes/{{id do processo}}/history```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}/history" --header "Authorization: Bearer {{meu token}}"```

+ Definir estado:

	**Requisição	:** ```POST /cockpit/processes/{{id do processo}}/state```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/cockpit/processes/{{id do processo}}/state" --header "Authorization: Bearer {{meu token}}"```
		
+ Atualizar:
	+ Abortar

		**Requisição	:** ```POST /cockpit/processes/{{id do processo}}/abort```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/cockpit/processes/{{id do processo}}/state" --header "Authorization: Bearer {{meu token}}"```

	+ Sobrescrever estado:
	
		**Requisição	:** ```POST /cockpit/processes/{{id do processo}}/state```
		**Comando		:**  ```curl --location --request GET "{{meu host}}/cockpit/processes/{{id do processo}}/state" --header "Authorization: Bearer {{meu token}}"```

	+ Retomar:
			**Requisição	:** ```POST /cockpit/processes/{id do processo}/state/run```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/cockpit/processes/{{id do processo}}/state/run" --header "Authorization: Bearer {{meu token}}"```
	
3.  Activity Managers (Tarefas):

+ Listar: 
			
	**Requisição	:** ```GET "{{meu host}}/processes"```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/processes" --header "Authorization: Bearer {{meu token}}"```
		
+ Disponíveis:

	**Requisição	:** ```GET /processes/available```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/cockpit/processes/{{id do processo}}/state/run" --header "Authorization: Bearer {{meu token}}"```

+ Concluídas:

	**Requisição	:** ```GET /processes/done```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/done" --header "Authorization: Bearer {{meu token}}" ```

+ Consultar _Activity Manager_  relacionado a um processo:

	**Requisição	:** ```GET /processes/{{id do processo}}/activity```
	**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}/activity" --header "Authorization: Bearer {{meu token}}" ```

+ Atualizar
	+ Salvar:
		+ ```{{id do processo}}```

			**Requisição	:** ```POST  /processes/{{id do processo}}/commit```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}/commit" --header "Authorization: Bearer {{meu token}}" ```

		+ ```{{id do activity manager}}```

			**Requisição	:** ```POST  /activity_manager/{{id do activity manager}}/commit ```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/activity_manager/{{id do activity manager}}/commit " --header "Authorization: Bearer {{meu token}}" ```
	
	+ Enviar:
		
		+ ```{{id do processo}}```
		
			**Requisição	:** ```POST /processes/{{id do processo}}/push```
						**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}/push" --header "Authorization: Bearer {{meu token}}" ```
				
		+ ```{{id do activity manager}}```			

			**Requisição	:** ```POST /activity_manager/{activity_manager_id}/push```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/activity_manager/{{id do activity manager}}/push" --header "Authorization: Bearer {{meu token}}"```
		
	+ Submeter:
		+ ```{{id do processo}}```

			**Requisição	:** ```POST /processes/{{id do processo}}/push```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/processes/{{id do processo}}/push" --header "Authorization: Bearer {{meu token}}" ```

		+  ```{{id do activity manager}}```

			**Requisição	:** ```POST /activity_manager/{{id do activity manager}}/submit ```
			**Comando		:**  ```curl --location --request GET "{{meu host}}/activity_manager/{{id do activity manager}}/submit " --header "Authorization: Bearer {{meu token}}" ```

## Referências:

[1] O que é uma engine: https://en.wikipedia.org/wiki/Software_engine
