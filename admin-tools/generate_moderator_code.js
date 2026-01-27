/**
 * Admin Script to Generate Moderator Verification Codes
 * Run this script with Node.js to create verification codes and send emails
 * 
 * Setup:
 * 1. npm install firebase-admin nodemailer
 * 2. Download your Firebase service account key JSON
 * 3. Set up email credentials (Gmail recommended)
 * 4. Run: node generate_moderator_code.js
 */

const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin
const serviceAccount = require('./serviceAccountKey.json'); // Download from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Email configuration (using Gmail as example)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'wanyingxuan1210@gmail.com', 
    pass: 'kldt dqbe losi qkxb'      
  }
});

/**
 * Generate a random verification code
 */
function generateVerificationCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

/**
 * Create verification code in Firestore
 */
async function createVerificationCode(email) {
  const code = generateVerificationCode();
  
  await db.collection('moderatorCodes').doc(code).set({
    email: email,
    code: code,
    used: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 days from now
    )
  });
  
  return code;
}

/**
 * Send verification code via email
 */
async function sendVerificationEmail(email, code) {
  const mailOptions = {
    from: 'your-email@gmail.com',
    to: email,
    subject: 'Your Moderator Verification Code',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            margin: 0;
            padding: 0;
          }
          .container {
            max-width: 600px;
            margin: 50px auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
          }
          .header {
            text-align: center;
            color: #673AB7;
            margin-bottom: 30px;
          }
          .code-box {
            background: #673AB7;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 8px;
            font-size: 32px;
            font-weight: bold;
            letter-spacing: 5px;
            margin: 30px 0;
          }
          .info {
            color: #666;
            line-height: 1.6;
          }
          .warning {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 20px 0;
            color: #856404;
          }
          .footer {
            text-align: center;
            color: #999;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1>🛡️ Moderator Access Code</h1>
          </div>
          
          <div class="info">
            <p>Hello,</p>
            <p>You have been granted access to the Community Contribution Moderator Dashboard.</p>
            <p>Your verification code is:</p>
          </div>
          
          <div class="code-box">
            ${code}
          </div>
          
          <div class="info">
            <h3>How to use this code:</h3>
            <ol>
              <li>Go to the moderator login page</li>
              <li>Create an account (if you haven't already) or sign in</li>
              <li>Enter this verification code when prompted</li>
              <li>You will gain access to the moderator dashboard</li>
            </ol>
          </div>
          
          <div class="warning">
            <strong>⚠️ Important:</strong>
            <ul style="margin: 10px 0 0 0; padding-left: 20px;">
              <li>This code expires in 7 days</li>
              <li>This code can only be used once</li>
              <li>Do not share this code with anyone</li>
              <li>If you didn't request this, please contact the administrator</li>
            </ul>
          </div>
          
          <div class="footer">
            <p>This is an automated message. Please do not reply to this email.</p>
            <p>&copy; 2025 Community Contribution Platform</p>
          </div>
        </div>
      </body>
      </html>
    `
  };
  
  await transporter.sendMail(mailOptions);
}

/**
 * Main function - Add a new moderator
 */
async function addModerator(email) {
  try {
    console.log(`\n🔄 Generating verification code for ${email}...`);
    
    // Generate and save code
    const code = await createVerificationCode(email);
    console.log(`✅ Code generated: ${code}`);
    
    // Send email
    console.log(`📧 Sending email to ${email}...`);
    await sendVerificationEmail(email, code);
    console.log(`✅ Email sent successfully!`);
    
    console.log(`\n✨ Moderator verification code created successfully!`);
    console.log(`   Email: ${email}`);
    console.log(`   Code: ${code}`);
    console.log(`   Expires: 7 days from now\n`);
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
}

/**
 * List all verification codes
 */
async function listAllCodes() {
  try {
    const snapshot = await db.collection('moderatorCodes').get();
    
    console.log('\n📋 All Verification Codes:\n');
    console.log('Code\t\tEmail\t\t\t\tUsed\tExpires');
    console.log('─'.repeat(80));
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const expiresAt = data.expiresAt ? data.expiresAt.toDate().toLocaleDateString() : 'N/A';
      console.log(
        `${doc.id}\t${data.email}\t${data.used ? '✓' : '✗'}\t${expiresAt}`
      );
    });
    
    console.log('\n');
  } catch (error) {
    console.error('❌ Error listing codes:', error);
  }
}

/**
 * Delete a verification code
 */
async function deleteCode(code) {
  try {
    await db.collection('moderatorCodes').doc(code).delete();
    console.log(`✅ Code ${code} deleted successfully`);
  } catch (error) {
    console.error('❌ Error deleting code:', error);
  }
}

// Command line interface
const args = process.argv.slice(2);
const command = args[0];

if (command === 'add' && args[1]) {
  addModerator(args[1]).then(() => process.exit(0));
} else if (command === 'list') {
  listAllCodes().then(() => process.exit(0));
} else if (command === 'delete' && args[1]) {
  deleteCode(args[1]).then(() => process.exit(0));
} else {
  console.log(`
╔════════════════════════════════════════════════════════════════╗
║      Moderator Verification Code Generator                     ║
╚════════════════════════════════════════════════════════════════╝

Usage:
  node generate_moderator_code.js <command> [options]

Commands:
  add <email>     Generate a code and send it to the email
  list            List all verification codes
  delete <code>   Delete a specific verification code

Examples:
  node generate_moderator_code.js add moderator@example.com
  node generate_moderator_code.js list
  node generate_moderator_code.js delete ABC12345

Setup Instructions:
1. Download your Firebase service account key from:
   Firebase Console → Project Settings → Service Accounts
   
2. Save it as 'serviceAccountKey.json' in this directory

3. Configure email settings in this script:
   - Update the email/password in the transporter config
   - For Gmail: Use an App Password, not your regular password
   - Generate App Password: https://myaccount.google.com/apppasswords

4. Install dependencies:
   npm install firebase-admin nodemailer
  `);
  process.exit(1);
}