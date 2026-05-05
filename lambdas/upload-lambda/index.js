import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import busboy from 'busboy';
import { v4 as uuidv4 } from 'uuid';

const s3Client = new S3Client();

export const handler = async (event) => {
  console.log("evento recibido:", JSON.stringify(event));

  // solo aceptamos post
  if (event.requestContext.http.method !== 'POST') {
    return { statusCode: 405, body: 'Metodo no permitido' };
  }

  const contentType = event.headers['content-type'] || event.headers['Content-Type'] || '';
  
  // chequear si es multipart
  if (!contentType.includes('multipart/form-data')) {
    return { statusCode: 400, body: 'Falta content-type correcto' };
  }

  return new Promise((resolve, reject) => {
    // configurar busboy
    const bb = busboy({ headers: { 'content-type': contentType } });
    const promises = []; 
    let processedFile = false; 

    bb.on('file', (name, file, info) => {
      processedFile = true;
      const { filename, encoding, mimeType } = info;
      console.log(`analizando archivo: ${filename}`);
      
      // tipos permitidos
      const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
      if (!allowedMimeTypes.includes(mimeType)) {
        file.resume(); 
        resolve({ statusCode: 400, body: 'Tipo no permitido' });
        return;
      }

      // leer la imagen
      const chunks = [];
      file.on('data', (data) => {
        chunks.push(data);
      });

      file.on('end', () => {
        const fileBuffer = Buffer.concat(chunks);
        
        // validar tamano
        if (fileBuffer.length > 10 * 1024 * 1024) { 
           resolve({ statusCode: 413, body: 'Muy grande, max 10MB' });
           return;
        }

        const extension = mimeType.split('/')[1];
        const key = `${process.env.UPLOAD_PREFIX || 'uploads/'}${uuidv4()}.${extension}`;
        
        console.log(`subiendo a s3: ${key}`);

        // mandar a s3
        const uploadPromise = s3Client.send(new PutObjectCommand({
          Bucket: process.env.S3_BUCKET,
          Key: key,
          Body: fileBuffer,
          ContentType: mimeType,
          Metadata: { originalName: filename }
        })).then(() => {
          return key;
        }).catch((err) => {
          console.error("error s3:", err);
          throw err;
        });

        promises.push(uploadPromise);
      });
    });

    // cuando termina
    bb.on('finish', async () => {
      if (!processedFile) {
         resolve({ statusCode: 400, body: 'No hay archivo' });
         return;
      }
      
      try {
        const keys = await Promise.all(promises);
        
        resolve({
          statusCode: 200,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: 'Subido correctamente', keys: keys })
        });
      } catch (err) {
        resolve({
          statusCode: 500,
          body: 'Error en servidor'
        });
      }
    });

    bb.on('error', (err) => {
      console.error('error de busboy:', err);
      resolve({ statusCode: 500, body: 'Error analizando' });
    });

    try {
      // pasarle los datos a busboy
      const bodyBuffer = event.isBase64Encoded 
          ? Buffer.from(event.body, 'base64') 
          : Buffer.from(event.body);
          
      bb.write(bodyBuffer);
      bb.end();
    } catch(err) {
      console.error('error de body:', err);
      resolve({ statusCode: 500, body: 'Error procesando body' });
    }
  });
};
