import Foundation

extension Date {
    var eventTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return f.string(from: self)
    }

    var detailTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE · h:mm a"
        return f.string(from: self)
    }

    var inviteString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return f.string(from: self)
    }

    var dayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: self)
    }
}
