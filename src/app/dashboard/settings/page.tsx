"use client";

import { createSupabaseBrowserClient } from "@/lib/supabase/client";
import { create } from "domain";
import { useRouter } from "next/navigation";

export default function SettingsPage() {
    const router = useRouter();
    const supabase = createSupabaseBrowserClient();

    const handleLogout = async () => {
        await supabase.auth.signOut();
        router.push("/login");
        router.refresh();
    };

    return (
        <div className="h-full flex justify-center items-center">
            <button onClick={handleLogout} className=" bg-red-600">
                Log Out
            </button>
        </div>
    );
}
