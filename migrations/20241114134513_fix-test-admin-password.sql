-- Add migration script here
UPDATE users 
SET password_hash = '$argon2id$v=19$m=15000,t=2,p=1$+10Kho6M2CW2lFTRHZ30nQ$seW/uWE65ZQDCqpE7OW+q7wma2C0xWsfhXhGGKmBtl0'
WHERE user_id = 'ddf8994f-d522-4659-8d02-c1d479057be6';
