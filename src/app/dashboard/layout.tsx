import Sidebar from "@/components/Sidebar"
import "@/app/globals.css"

export default function DashboardLayout( {children}: { children: React.ReactNode} ) {
    return <div className="flex flex-row">
        <Sidebar />
        {children}
    </div>
}