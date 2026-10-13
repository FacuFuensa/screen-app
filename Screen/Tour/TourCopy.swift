import ScreenCore

enum TourCopy {
    static func title(_ step: TourStep) -> String {
        switch step {
        case .permissions: return "Dos permisos"
        case .newLimit: return "Empecemos por un límite"
        case .name: return "Ponele un nombre"
        case .apps: return "Elegí las apps"
        case .minutes: return "¿Cuánto por día?"
        case .save: return "Listo, guardalo"
        case .invite: return "Ahora, tu dupla"
        case .share: return "Compartí el código"
        }
    }

    static func message(_ step: TourStep) -> String {
        switch step {
        case .permissions:
            return "Te van a aparecer dos avisos de Apple: tocá Continuar y después Permitir."
        case .newLimit:
            return "Tocá Nuevo límite para elegir qué apps querés controlar."
        case .name:
            return "Cualquiera que te sirva, por ejemplo Redes. Cuando termines, tocá Listo en el teclado."
        case .apps:
            return "Se abre una lista de Apple: tocá las apps que querés limitar (TikTok, Instagram…) o una categoría entera, y después Listo."
        case .minutes:
            return "Tocá + o − para elegir. Arrancá generoso: bajarlo después es libre, subirlo lo aprueba tu dupla."
        case .save:
            return "Tocá el botón para crear tu límite."
        case .invite:
            return "Screen funciona de a dos. Tocá acá para invitar a la otra persona."
        case .share:
            return "Tocá Crear código y mandáselo. Si a vos te pasaron un código, escribilo abajo."
        }
    }
}
