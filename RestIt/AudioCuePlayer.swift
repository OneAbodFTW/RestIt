import AppKit

@MainActor
final class AudioCuePlayer {
    enum Cue {
        case eyeBreakStarted
        case eyeBreakFinished
        case waterReminder

        var soundName: NSSound.Name {
            switch self {
            case .eyeBreakStarted: return NSSound.Name("Glass")
            case .eyeBreakFinished: return NSSound.Name("Tink")
            case .waterReminder: return NSSound.Name("Bottle")
            }
        }
    }

    private var currentSound: NSSound?

    func play(_ cue: Cue, volume: Double) {
        currentSound?.stop()

        guard let sound = NSSound(named: cue.soundName) else {
            NSSound.beep()
            return
        }

        sound.volume = Float(min(max(volume, 0), 1))
        currentSound = sound
        sound.play()
    }
}

