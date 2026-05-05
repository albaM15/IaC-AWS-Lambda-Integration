import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import sharp from 'sharp';
import path from 'path';

const s3Client = new S3Client();

export const handler = async (event) => {
  console.log("Evento SQS recibido");

  // lista de fallos
  const batchItemFailures = [];

  for (const record of event.Records) {
    try {
      const sqsBody = JSON.parse(record.body);
      
      // ignorar eventos de prueba
      if (sqsBody.Event === 's3:TestEvent') {
        continue;
      }

      const s3Records = sqsBody.Records || [];

      for (const s3Record of s3Records) {
        const bucket = s3Record.s3.bucket.name;
        const key = decodeURIComponent(s3Record.s3.object.key.replace(/\+/g, ' '));
        
        console.log(`procesando archivo: ${key}`);

        // traer imagen de s3
        const getObjectResponse = await s3Client.send(new GetObjectCommand({
          Bucket: bucket,
          Key: key
        }));

        const chunks = [];
        for await (const chunk of getObjectResponse.Body) {
          chunks.push(chunk);
        }
        const imageBuffer = Buffer.concat(chunks);

        const size = 40; 
        
        // crear mascara circular en svg
        const circleSvg = `<svg width="${size}" height="${size}">
          <circle cx="${size/2}" cy="${size/2}" r="${size/2}" fill="white" />
        </svg>`;

        // recortar la imagen
        const processedImageBuffer = await sharp(imageBuffer)
          .resize(size, size, { fit: 'cover' })
          .composite([{
            input: Buffer.from(circleSvg),
            blend: 'dest-in'
          }])
          .png({ alpha: true }) 
          .toBuffer();

        // armar el nuevo nombre
        const filename = path.basename(key);
        const nameWithoutExt = filename.substring(0, filename.lastIndexOf('.')) || filename;
        const newKey = `${process.env.PROCESSED_PREFIX || 'processed/'}${nameWithoutExt}_circular.png`;

        console.log(`guardando en: ${newKey}`);

        // subir imagen procesada
        await s3Client.send(new PutObjectCommand({
          Bucket: bucket,
          Key: newKey,
          Body: processedImageBuffer,
          ContentType: 'image/png'
        }));
      }

    } catch (err) {
      console.error(`error en el mensaje ${record.messageId}:`, err);
      // si falla lo agregamos a la lista
      batchItemFailures.push({ itemIdentifier: record.messageId });
    }
  }

  // devolver fallos para que reintente
  return { batchItemFailures };
};
