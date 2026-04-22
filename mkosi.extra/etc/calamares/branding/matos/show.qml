import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() {
        if (!timer.running)
            timer.start()
        presentation.goToNextSlide()
    }

    Timer {
        id: timer
        interval: 4000
        repeat: true
        running: false
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"
            Column {
                anchors.centerIn: parent
                spacing: 20
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Bienvenue dans matOS RALAMBO"
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e0e0e0"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Distribution Linux pour les mathématiques"
                    font.pixelSize: 18
                    color: "#4a9eff"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SageMath • GAP • PARI/GP • Singular • Maxima • R • LaTeX"
                    font.pixelSize: 14
                    color: "#aaaaaa"
                }
            }
        }
    }

    Slide {
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            color: "#1a1a2e"
            Column {
                anchors.centerIn: parent
                spacing: 20
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Installation en cours..."
                    font.pixelSize: 28
                    font.bold: true
                    color: "#e0e0e0"
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Veuillez patienter pendant la copie du système"
                    font.pixelSize: 16
                    color: "#aaaaaa"
                }
            }
        }
    }

    Component.onCompleted: presentation.goToNextSlide()
}
