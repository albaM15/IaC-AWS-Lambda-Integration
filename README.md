# Image Processor — IaC con AWS Lambda

Sistema serverless para procesamiento de imágenes en AWS. El usuario sube una imagen por API, se almacena en S3, una cola SQS notifica al segundo Lambda y este la recorta en forma circular automáticamente.

Toda la infraestructura se despliega con Terraform.

## Servicios AWS

- API Gateway v2
- Lambda
- S3
- SQS
- CloudWatch
- SNS
- VPC

## Requisitos

- Terraform >= 1.0
- AWS CLI v2
- Node.js >= 20.x
- Credenciales de AWS configuradas (`aws configure`)

## Despliegue

Primero instalar las dependencias de los Lambdas:

```bash
cd lambdas/upload-lambda && npm install && cd ../..
cd lambdas/crop-lambda && npm install && cd ../..
```

Crear el archivo `terraform.tfvars` en la raíz del proyecto con tus valores:

```hcl
suffix   = "tu-nombre"
region   = "us-east-1"
vpc_cidr = "10.0.0.0/16"
```

Después inicializar Terraform y crear un workspace:

```bash
cd terraform
terraform init
terraform workspace new dev
```

Revisar qué se va a crear y desplegar:

```bash
terraform plan
terraform apply
```

Al finalizar se muestran los outputs con la URL del API, el nombre del bucket y la URL de la cola.

## Probar

```bash
curl -X POST \
  "$(terraform output -raw api_endpoint)" \
  -F "image=@/ruta/a/tu/imagen.jpg"
```

```json
{
  "message": "Subido correctamente",
  "keys": ["uploads/uuid-generado.jpeg"]
}
```

La imagen recortada aparece en `processed/` dentro del bucket en unos segundos.

## Destruir

```bash
terraform destroy
```

El bucket tiene `force_destroy = true`, así que se elimina aunque tenga objetos.

## Workspaces

El proyecto usa Terraform Workspaces para manejar ambientes. Cada workspace crea recursos con nombres independientes, por ejemplo `image-processor-dev-upload` y `image-processor-prod-upload`.

```bash
terraform workspace new qa
terraform workspace select prod
```
