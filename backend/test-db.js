const { createClient } = require('@supabase/supabase-js');
require('dotenv').config({ path: '.env.local' });

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('SUPABASE_URL:', url);
console.log('SERVICE_ROLE_KEY:', serviceKey ? serviceKey.substring(0, 20) + '...' : 'MISSING');

if (!url || !serviceKey || serviceKey === 'YOUR_SERVICE_ROLE_KEY') {
  console.error('\n❌ CRITICAL: Missing SUPABASE_SERVICE_ROLE_KEY in .env.local!');
  console.error('This is the ROOT CAUSE of sync failures.\n');
  console.error('Steps to fix:');
  console.error('1. Go to: https://qftxkxdqrmeebwrhspdn.supabase.co/project/qftxkxdqrmeebwrhspdn/settings/api');
  console.error('2. Copy the "service_role" key (NOT anon key)');
  console.error('3. Update .env.local: SUPABASE_SERVICE_ROLE_KEY=<paste key here>');
  console.error('4. Run: vercel env add SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

async function testDatabase() {
  const supabase = createClient(url, serviceKey);
  
  console.log('\n🔍 Testing database connection...\n');
  
  // Test 1: Check if tables exist
  const { data: tables, error: tableError } = await supabase
    .from('wordbooks')
    .select('id')
    .limit(1);
  
  if (tableError) {
    console.error('❌ Table check failed:', tableError.message);
    if (tableError.message.includes('relation') || tableError.message.includes('does not exist')) {
      console.error('\n❌ CRITICAL: Database tables do NOT exist!');
      console.error('You must run the schema setup:\n');
      console.error('1. Go to: https://qftxkxdqrmeebwrhspdn.supabase.co/project/qftxkxdqrmeebwrhspdn/sql/new');
      console.error('2. Copy the contents of backend/supabase/schema.sql');
      console.error('3. Paste and run it in the SQL Editor');
    }
  } else {
    console.log('✅ Database tables exist');
    console.log('   Found', tables ? tables.length : 0, 'wordbooks');
  }
  
  // Test 2: Check auth tables
  const { data: authData, error: authError } = await supabase.auth.admin.listUsers({ perPage: 1 });
  if (authError) {
    console.error('❌ Auth check failed:', authError.message);
  } else {
    console.log('✅ Auth system working');
  }
}

testDatabase().catch(console.error);
