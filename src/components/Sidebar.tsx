"use client";

import { usePathname } from "next/navigation";
import { useState } from "react";
import NavContent from "@/components/navContent";
import { Menu, ChartArea } from "lucide-react";

export default function Sidebar() {

  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  return (
    <>
      {/* Desktop sidebar */}
      <nav className="w-50 h-screen bg-white py-4 border-r border-gray-200 hidden md:block">
        <NavContent onClose={() => setMobileOpen(false)} />
      </nav>

      {/* Top bar on mobile*/}
      <div className="flex gap-5 items-center ml-4 w-screen h-15 border-b border-gray-200 md:hidden">
        <button
          onClick={() => setMobileOpen(true)}
          className="p-1.5 rounded-xl hover:bg-zinc-200 transition-colors duration-200 "
        >
          <Menu className="h-4" />
        </button>
        <div className="flex flex-row items-center">
          <ChartArea className="w-4" />
          <h1 className="font-medium text-[15px]">Real Margin</h1>
        </div>
      </div>

      {mobileOpen && (
        <>

        </>

      )}
    </>
  );
}
