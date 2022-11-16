# Flowbuild engine 

A documentação oficial da engine [1] FlowBuild encontra-se em https://flow-build.github.io/ . Este arquivo não pretende substituir o original, mas a servir o usuário que esteja na lida diária de uso do workflow. Portanto, ele sumariza, de forma unificada, as informações necessárias para utilizá-lo. 

## Pré-requisitos

- OS utilizado: distribuição Linux da sua preferência
- Instruções a usuários Windows: acompanhar passos abaixo e adaptar através de ferramentas _Postman_ ou _Insomnia_ (URL: https://flow-build.github.io/docs/documentation/instalacao)

## Recomendação inicial

Os comandos ```curl```s desta seção, quando realizados no terminal, vem em formato .json sem indentação e breakline no final. O autor deste tutorial recomenda copiar estes valores json e usar a ferramenta disponível no URL a seguir para formatá-los: https://jsonformatter.org/.

## Vocabulário

A ferramenta Flowbuild utiliza alguns artefatos e ações pertinentes ao contexto de processos. Em linhas gerais, nós apresentamos abaixo as principais palavras referentes ao contexto:

1. Workflow: um artefato de fluxo, comumente descrito como diagrama;
2. Task: um bloco de um workflow, comumente descrito como `nó`. As tasks existentes até o momento são: `start`, `finish`, `systemtask`, `subprocess`, `scripttask`, `flow`, `usertask`;
3. Processo: uma instância de um artefato workflow;
4. Estado: um retrato temporal minimo de um processo; 
4. Activity Manager: do inglês "gerente de atividade", é um entidade que gerencia as atividades de um nó de interface com usuário (User task);

## Como configurar

Até o momento da confecção deste tutorial, a ferramenta FlowBuild não dispõem lançamento de interface estável. Escolha um diretório de sua preferência, o qual referenciamos como `$WORKFLOW_PATH`. Desta forma, as instruções necessárias para utilizar o documento seguem 

1) Clonar https://github.com/flow-build/workflow-api em ```$WORKFLOW_PATH```;
2) Navegue até o diretório ```$WORKFLOW_PATH``` e suba o servidor: 

	```sudo docker-compose up```

3) Gerar token com comando abaixo por (terminal || Postman || Insomnia) ou URL jwt.io. Os campos ```{{new_password}}``` e ```{{duração}}``` são opcionais e à escolha do usuário: 

	```curl --location --request POST "{{host_url}}/token" --header 'x-secret: {{new_password}}' --header 'x-duration: {{duração}}' --header 'Content-Type: application/json'```
	
**Lembre-se:** A senha 'x-secret' padrão  é 1234 e a duração de expiração 'x-duration' padrão 60000 [s], i.e. 1 hora. O autor deste tutorial recomenda utilizar 1 dia (1440000 = [24 h]*[60 min]*[1000 ms]) para realizar este tutorial.

**Tome nota**: O cliente (quem faz a requisição) sabe sobre o uso da chave JWT pelo servidor. Desta forma, não é necessario e suficiente o uso do comando acima. Ou seja, qualquer chave que siga as regras JWT é válido, e.g. gerado pelo URL jwt.io ;

**Lembre-se:** Você deve usar a chave gerada a partir daqui no lugar de ```{{jwt_token}}```;

4) Substituir chave do ```JWT_KEY``` em .env.docker pelo token do passo anterior

## Como usar

Caso queira testar com uma blueprint válida, utilize o exemplo ```simple_bp.json``` presente neste diretório. Abaixo encontram-se as opções possíveis para utilização da *engine* Flowbuild. As chamadas ```curl``` podem ser executadas no terminal. 

Os campos ```{{host_url}}```, ```{{jwt_token}}```, ```{{new_password}}``` e ```{{workflow_json}}``` são respectivamente: 

- o link do servidor;
- Um token válido (Se ele expirou, siga os passos da sessão "Configuração" a partir do item 3))
- Senha cadastrada na sessão "Configuração", item 3)

**Tome nota**: Substituir o trecho ```{{host_url}}``` por ```localhost:3000```.

Abaixo, as opões enumeradas correpondem a entidades e suas ações de gerenciamento da _engine_:

1) Workflows cadastrados:

+ Listar:

	**Requisição	:** ```GET /workflows```
	
	**Comando       :** ``curl --location --request GET "{{host_url}}/workflows" --header "Authorization: Bearer {{jwt_token}}" --header "x-secret={{new_password}}"``

+ Criar/Atualizar:

	**Requisição	:** ```POST /workflows```
	
	**Comando		:**  ```curl --location --request POST "{{host_url}}/workflows" --header 'content: application/json' --header 'Content-Type: application/json' --header "Authorization: Bearer {{jwt_token}}" --data-raw {{workflow_json}}```
	
+ Consultar por:
	- ```{{workflow_id}}```:
	
		**Requisição	:** ```GET /workflows/{{workflow_id}}```
		
		**Comando		:** ```curl --location --request GET "{{host_url}}/workflows/{{workflow_id}}" --header "Authorization: Bearer {{jwt_token}}" --header "x-secret={{new_password}}"```

	- ```{{workflow_name}}```:

		**Requisição	:** ```GET /workflows/name/{{workflow_name}}```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/workflows/name/{{workflow_name}}" --header "Authorization: Bearer {{jwt_token}}" --header "x-secret={{new_password}}"```

2) Processos cadastrados:

+ Listar

	**Requisição	:** ```GET "{{host_url}}/processes"```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes" --header "Authorization: Bearer {{jwt_token}}"```

+ Criar: 
	
	**Requisição	:** ```GET /workflows/{workflow_id}/processes```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/workflows/{{workflow_id}}/processes" --header "Authorization: Bearer {{jwt_token}}"```

+ Iniciar:

	+ Chave ```{{workflow_id}}```
		
		**Requisição	:** ```GET /workflows/{workflow_id}/processes```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/workflows/{{workflow_id}}/processes" --header "Authorization: Bearer {{jwt_token}}"```

	+ Chave ```{{nome do workflow}}```
	
		**Requisição	:** ```/workflows/name/{workflow_name}/start```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/workflows/name/{{nome do workflow}}/start" --header "Authorization: Bearer {{jwt_token}}"```

+ Ler: 

	**Requisição	:** ```GET /workflows/{{workflow_id}}/processes```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/workflows/{{workflow_id}}/processes" --header "Authorization: Bearer {{jwt_token}}"```

+ Acompanhar:

	**Requisição	:** ```GET /processes/{{process_id}}```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/{{process_id}}" --header "Authorization: Bearer {{jwt_token}}"```

+ Consultar histórico:

	**Requisição	:** ```GET /processes/{{process_id}}/history```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/{{process_id}}/history" --header "Authorization: Bearer {{jwt_token}}"```

+ Definir estado:

	**Requisição	:** ```POST /cockpit/processes/{{process_id}}/state```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/cockpit/processes/{{process_id}}/state" --header "Authorization: Bearer {{jwt_token}}"```
		
+ Atualizar:

	+ Abortar

		**Requisição	:** ```POST /cockpit/processes/{{process_id}}/abort```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/cockpit/processes/{{process_id}}/state" --header "Authorization: Bearer {{jwt_token}}"```

	+ Sobrescrever estado:
	
		**Requisição	:** ```POST /cockpit/processes/{{process_id}}/state```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/cockpit/processes/{{process_id}}/state" --header "Authorization: Bearer {{jwt_token}}"```

	+ Retomar:
	
		**Requisição	:** ```POST /cockpit/processes/{process_id}/state/run```
		
		**Comando		:**  ```curl --location --request GET "{{host_url}}/cockpit/processes/{{process_id}}/state/run" --header "Authorization: Bearer {{jwt_token}}"```
	
3.  Activity Managers (Tarefas):

+ Listar: 
			
	**Requisição	:** ```GET "{{host_url}}/processes"```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes" --header "Authorization: Bearer {{jwt_token}}"```
		
+ Disponíveis:

	**Requisição	:** ```GET /processes/available```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/cockpit/processes/{{process_id}}/state/run" --header "Authorization: Bearer {{jwt_token}}"```

+ Concluídas:

	**Requisição	:** ```GET /processes/done```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/done" --header "Authorization: Bearer {{jwt_token}}" ```

+ Consultar _Activity Manager_  relacionado a um processo:

	**Requisição	:** ```GET /processes/{{process_id}}/activity```
	
	**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/{{process_id}}/activity" --header "Authorization: Bearer {{jwt_token}}" ```

+ Atualizar

	+ Salvar:

		+ ```{{process_id}}```

			**Requisição	:** ```POST  /processes/{{process_id}}/commit```
			
			**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/{{process_id}}/commit" --header "Authorization: Bearer {{jwt_token}}" ```

		+ ```{{activity_manager_id}}```

			**Requisição	:** ```POST  /activity_manager/{{activity_manager_id}}/commit ```
			
			**Comando		:**  ```curl --location --request GET "{{host_url}}/activity_manager/{{activity_manager_id}}/commit " --header "Authorization: Bearer {{jwt_token}}" ```
	
	+ Submeter:

		+ ```{{process_id}}```

			**Requisição	:** ```POST /processes/{{process_id}}/push```
			
			**Comando		:**  ```curl --location --request GET "{{host_url}}/processes/{{process_id}}/push" --header "Authorization: Bearer {{jwt_token}}" ```

		+  ```{{activity_manager_id}}```

			**Requisição	:** ```POST /activity_manager/{{activity_manager_id}}/submit ```
			
			**Comando		:**  ```curl --location --request GET "{{host_url}}/activity_manager/{{activity_manager_id}}/submit " --header "Authorization: Bearer {{jwt_token}}" ```

## Referências

[1] O que é uma engine: https://en.wikipedia.org/wiki/Software_engine
[2] O que é a ferramenta Flowbuild: https://flow-build.github.io/
