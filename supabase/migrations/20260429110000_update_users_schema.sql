-- 1. Add full_name and make organization_id nullable
-- This allows users to exist without being tied to an organization immediately.
ALTER TABLE public.users ADD COLUMN full_name TEXT;
ALTER TABLE public.users ALTER COLUMN organization_id DROP NOT NULL;

-- 2. Create a function to handle new user signups
-- This function will automatically create a row in public.users when a user
-- signs up via Supabase Auth. It extracts the 'full_name' from the user metadata.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, role)
  VALUES (
    new.id, 
    new.email, 
    new.raw_user_meta_data->>'full_name',
    'owner'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger the function every time a user is created in Auth
-- This connects Supabase Auth to your public.users table.
-- Using DROP/CREATE to ensure it's idempotent if you run this multiple times.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
