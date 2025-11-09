const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

const url = process.env.SUPABASE_URL;
const anonKey = process.env.SUPABASE_ANON_KEY;
const apiBaseURL = 'https://hulu-beici-backend.vercel.app';

console.log('\n🧪 Testing Wordbook API End-to-End\n');

async function testWordbookAPI() {
  // Step 1: Create a test user session
  console.log('1️⃣ Creating Supabase client...');
  const supabase = createClient(url, anonKey);

  // Get existing user or use credentials
  console.log('\n2️⃣ Attempting to sign in with test user...');
  console.log('   ⚠️  You need to provide a test email and password');
  console.log('   💡 Run this script like: node test-wordbook-api.js email@example.com password');

  const testEmail = process.argv[2];
  const testPassword = process.argv[3];

  if (!testEmail || !testPassword) {
    console.error('\n❌ Please provide email and password as arguments');
    console.error('   Usage: node test-wordbook-api.js your-email@example.com your-password\n');
    process.exit(1);
  }

  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email: testEmail,
    password: testPassword
  });

  if (authError || !authData.session) {
    console.error('❌ Sign in failed:', authError?.message);
    return;
  }

  const accessToken = authData.session.access_token;
  console.log('✅ Signed in successfully');
  console.log('   User ID:', authData.user.id);
  console.log('   Access token:', accessToken.substring(0, 30) + '...');

  // Step 2: Test POST /api/wordbooks
  console.log('\n3️⃣ Testing wordbook creation API...');

  const testWordbook = {
    title: '测试词书 ' + Date.now(),
    subtitle: '自动测试创建',
    targetPasses: 1,
    words: [
      { word: 'test', meaning: '测试', ordinal: 0 },
      { word: 'hello', meaning: '你好', ordinal: 1 },
      { word: 'world', meaning: '世界', ordinal: 2 }
    ]
  };

  try {
    const response = await fetch(`${apiBaseURL}/api/wordbooks`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`
      },
      body: JSON.stringify(testWordbook)
    });

    const responseText = await response.text();
    console.log('   Response status:', response.status);
    console.log('   Response body:', responseText);

    if (!response.ok) {
      console.error('❌ API call failed with status:', response.status);
      return;
    }

    const result = JSON.parse(responseText);
    console.log('✅ Wordbook created successfully!');
    console.log('   ID:', result.wordbook.id);
    console.log('   Title:', result.wordbook.title);
    console.log('   Words count:', result.wordbook.entries?.length || 0);

    // Step 3: Verify in database
    console.log('\n4️⃣ Verifying wordbook exists in database...');
    const { data: wordbooks, error: dbError } = await supabase
      .from('wordbooks')
      .select('id, title, subtitle')
      .eq('id', result.wordbook.id)
      .single();

    if (dbError) {
      console.error('❌ Database verification failed:', dbError.message);
      return;
    }

    console.log('✅ Wordbook found in database!');
    console.log('   ', wordbooks);

    console.log('\n✨ All tests passed! Sync is working correctly.\n');

  } catch (error) {
    console.error('❌ Test failed with error:', error.message);
    console.error(error);
  }
}

testWordbookAPI().catch(console.error);
