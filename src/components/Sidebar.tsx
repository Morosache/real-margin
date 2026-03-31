"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, UsersRound, Settings, ChartArea} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();

  const routes = [
    { href: "/dashboard", label: "Dashboard", icon: <LayoutDashboard className="w-[18px] h-[18px]"/> },
    { href: "/dashboard/clients", label: "Clients", icon: <UsersRound className="w-[18px] h-[18px]" /> },
    { href: "/dashboard/settings", label: "Settings", icon: <Settings className="w-[18px] h-[18px]"/> },
  ];

  return (
    <nav className="w-[200px] h-screen bg-white py-4 border-r border-gray-200 hidden md:block">
      <div className="border-b border-gray-200 pb-4 flex items-center mt-2 pl-6">
        <ChartArea />
        <h1 className="text-center font-medium">Real Margin</h1>
      </div>
      <ul className="list-none px-4 mt-4 flex flex-col gap-1">
        {routes.map((route) => (
          <li key={route.href}>
            <Link
              href={route.href}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg no-underline font-medium text-sm text-zinc-500 ${
                pathname === route.href
                  ? "bg-zinc-900 px-3 py-2  rounded-xl text-white! transition-colors duration-200"
                  : "hover:text-zinc-900 hover:bg-zinc-100 transition-colors duration-200"
              }`}
            >
              {route.icon}
              {route.label}
            </Link>
          </li>
        ))}
      </ul>
    </nav>
  );
}
