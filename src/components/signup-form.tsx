"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase/client";

import { Button } from "@/components/ui/button";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from "@/components/ui/card";
import {
    Field,
    FieldDescription,
    FieldGroup,
    FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";

import Link from "next/link";

export function SignupForm({ ...props }: React.ComponentProps<typeof Card>) {
    const router = useRouter();
    const supabase = createSupabaseBrowserClient();

    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const [success, setSuccess] = useState(false);

    //signup submit handler
    const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        const formData = new FormData(e.currentTarget);
        const email = formData.get("email") as string;
        const password = formData.get("password") as string;
        const confirmPassword = formData.get("confirm-password") as string;

        // basic validation
        if (password !== confirmPassword) {
            setError("Passwords do not match");
            setLoading(false);
            return;
        }

        // call supabase
        const { data, error } = await supabase.auth.signUp({
            email,
            password,
            options: {
                data: {
                    full_name: formData.get("name") as string,
                },
                emailRedirectTo: `${window.location.origin}/auth/callback`,
            },
        });

        if (error) {
            setError(error.message);
            setLoading(false);
        } else {
            // If the user is logged in immediately (session exists)
            if (data.session) {
                router.push("/dashboard");
            } else {
                setSuccess(true);
                setLoading(false);
            }
            // Note: If email confirmation is ON in Supabase, they need to check their email.
            // If it's OFF, they are logged in immediately.
        }
    };
    return (
        <Card {...props}>
            <CardHeader>
                <CardTitle>Create an account</CardTitle>
                <CardDescription>
                    Enter your information below to create your account
                </CardDescription>
            </CardHeader>
            <CardContent>
                {success ? (
                    /* SUCCESS STATE - Shown only after signup */
                    <div className="flex flex-col gap-4 py-4 text-center">
                        <div
                            className="rounded-lg bg-green-50 p-4 text-green-700 border
      border-green-200"
                        >
                            <p className="text-sm font-semibold">
                                Verify your email
                            </p>
                            <p className="mt-1 text-xs">
                                We&apos;ve sent a confirmation link to your
                                inbox. Please click it to complete your
                                registration.
                            </p>
                        </div>
                        <Button variant="outline" asChild>
                            <Link href="/login">Back to Login</Link>
                        </Button>
                    </div>
                ) : (
                    /* FORM STATE - Shown by default */
                    <form onSubmit={handleSubmit}>
                        <FieldGroup>
                            <Field>
                                <FieldLabel htmlFor="name">
                                    Full Name
                                </FieldLabel>
                                <Input
                                    name="name"
                                    id="name"
                                    type="text"
                                    placeholder="John Doe"
                                    required
                                />
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="email">Email</FieldLabel>
                                <Input
                                    name="email"
                                    id="email"
                                    type="email"
                                    placeholder="m@example.com"
                                    required
                                />
                                <FieldDescription>
                                    We&apos;ll use this to contact you. We will
                                    not share your email with anyone else.
                                </FieldDescription>
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="password">
                                    Password
                                </FieldLabel>
                                <Input
                                    name="password"
                                    id="password"
                                    type="password"
                                    required
                                />
                                <FieldDescription>
                                    Must be at least 8 characters long.
                                </FieldDescription>
                            </Field>
                            <Field>
                                <FieldLabel htmlFor="confirm-password">
                                    Confirm Password
                                </FieldLabel>
                                <Input
                                    name="confirm-password"
                                    id="confirm-password"
                                    type="password"
                                    required
                                />
                                <FieldDescription>
                                    Please confirm your password.
                                </FieldDescription>
                            </Field>
                            <FieldGroup>
                                <Field>
                                    {error && (
                                        <p className="text-sm text-red-500 text-center font-medium">
                                            {error}
                                        </p>
                                    )}

                                    <Button type="submit" disabled={loading}>
                                        {loading
                                            ? "Creating..."
                                            : "Create Account"}
                                    </Button>
                                    <Button variant="outline" type="button">
                                        Sign up with Google
                                    </Button>
                                    <FieldDescription className="px-6 text-center">
                                        Already have an account?{" "}
                                        <Link href="/login">Sign in</Link>
                                    </FieldDescription>
                                </Field>
                            </FieldGroup>
                        </FieldGroup>
                    </form>
                )}
            </CardContent>
        </Card>
    );
}
