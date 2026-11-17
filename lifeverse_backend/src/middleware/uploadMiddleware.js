const path = require('path');
const fs = require('fs');
const multer = require('multer');
const crypto = require('crypto');

const UPLOAD_DIR = path.resolve(process.env.UPLOAD_DIR || path.join(__dirname, '../../uploads/capsules'));
const MAX_FILE_SIZE = 200 * 1024 * 1024;
const MAX_SINGLE_FILE_SIZE = 50 * 1024 * 1024;

fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const ALLOWED_TYPES = {
    jpg: ['image/jpeg'], jpeg: ['image/jpeg'], png: ['image/png'], gif: ['image/gif'], webp: ['image/webp'],
    mp4: ['video/mp4'], mov: ['video/quicktime'], avi: ['video/x-msvideo', 'video/avi'],
    mkv: ['video/x-matroska'], webm: ['video/webm'],
    mp3: ['audio/mpeg', 'audio/mp3'], wav: ['audio/wav', 'audio/x-wav'],
    m4a: ['audio/mp4', 'audio/x-m4a'],
    pdf: ['application/pdf'], doc: ['application/msword'],
    docx: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    txt: ['text/plain'], zip: ['application/zip', 'application/x-zip-compressed']
};

async function hasValidSignature(filePath, extension) {
    const handle = await fs.promises.open(filePath, 'r');
    try {
        const header = Buffer.alloc(16);
        const { bytesRead } = await handle.read(header, 0, header.length, 0);
        const starts = (...bytes) => bytesRead >= bytes.length && bytes.every((byte, index) => header[index] === byte);
        switch (extension) {
            case 'jpg':
            case 'jpeg': return starts(0xff, 0xd8, 0xff);
            case 'png': return starts(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a);
            case 'gif': return header.subarray(0, 6).toString('ascii').startsWith('GIF8');
            case 'webp': return starts(0x52, 0x49, 0x46, 0x46) && header.subarray(8, 12).toString('ascii') === 'WEBP';
            case 'mp4':
            case 'mov':
            case 'm4a': return header.subarray(4, 8).toString('ascii') === 'ftyp';
            case 'avi': return starts(0x52, 0x49, 0x46, 0x46) && header.subarray(8, 12).toString('ascii') === 'AVI ';
            case 'mkv':
            case 'webm': return starts(0x1a, 0x45, 0xdf, 0xa3);
            case 'mp3': return header.subarray(0, 3).toString('ascii') === 'ID3' || (starts(0xff) && (header[1] & 0xe0) === 0xe0);
            case 'wav': return starts(0x52, 0x49, 0x46, 0x46) && header.subarray(8, 12).toString('ascii') === 'WAVE';
            case 'pdf': return header.subarray(0, 5).toString('ascii') === '%PDF-';
            case 'doc': return starts(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1);
            case 'docx':
            case 'zip': return starts(0x50, 0x4b, 0x03, 0x04) || starts(0x50, 0x4b, 0x05, 0x06) || starts(0x50, 0x4b, 0x07, 0x08);
            case 'txt': return !header.subarray(0, bytesRead).includes(0x00);
            default: return false;
        }
    } finally {
        await handle.close();
    }
}

const storage = {
    _handleFile(req, file, callback) {
        const extension = path.extname(file.originalname).toLowerCase().slice(1);
        const filename = `${crypto.randomUUID()}.${extension}`;
        const filePath = path.join(UPLOAD_DIR, filename);
        const output = fs.createWriteStream(filePath, { flags: 'wx' });
        let fileSize = 0;
        let finished = false;

        const fail = error => {
            if (finished) return;
            finished = true;
            file.stream.unpipe(output);
            output.destroy();
            file.stream.resume();
            const removePartialFile = () => fs.unlink(filePath, () => callback(error));
            if (output.closed) removePartialFile();
            else output.once('close', removePartialFile);
        };

        file.stream.on('data', chunk => {
            if (finished) return;
            fileSize += chunk.length;
            req.lifeVerseUploadBytes = (req.lifeVerseUploadBytes || 0) + chunk.length;
            if (req.lifeVerseUploadBytes > MAX_FILE_SIZE) {
                fail(new multer.MulterError('LIMIT_FILE_SIZE', file.fieldname));
            }
        });
        file.stream.once('limit', () => fail(new multer.MulterError('LIMIT_FILE_SIZE', file.fieldname)));
        output.once('error', fail);
        output.once('finish', async () => {
            if (finished) return;
            try {
                if (!await hasValidSignature(filePath, extension)) {
                    const error = new Error('Uploaded file content does not match its declared file type.');
                    error.statusCode = 415;
                    throw error;
                }
                finished = true;
                callback(null, { destination: UPLOAD_DIR, filename, path: filePath, size: fileSize });
            } catch (error) {
                fail(error);
            }
        });

        file.stream.pipe(output);
    },

    _removeFile(req, file, callback) {
        fs.unlink(file.path, error => {
            if (error && error.code !== 'ENOENT') return callback(error);
            callback(null);
        });
    }
};

const upload = multer({
    storage,
    limits: {
        fileSize: MAX_SINGLE_FILE_SIZE,
        files: 20,
        fieldSize: 64 * 1024,
        fields: 20
    },
    fileFilter: (req, file, callback) => {
        const extension = path.extname(file.originalname).toLowerCase().slice(1);
        const acceptedMimes = ALLOWED_TYPES[extension];
        if (!acceptedMimes || !acceptedMimes.includes(String(file.mimetype).toLowerCase())) {
            const error = new Error(`File type is not allowed: ${file.originalname}`);
            error.statusCode = 415;
            return callback(error);
        }
        callback(null, true);
    }
});

module.exports = { upload, UPLOAD_DIR, MAX_FILE_SIZE };
