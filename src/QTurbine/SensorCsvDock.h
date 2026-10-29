/**********************************************************************

    Copyright (C) 2024 QBlade Sensor CSV extension

    This program is licensed under the Academic Public License
    (APL) v1.0; You can use, redistribute and/or modify it in
    non-commercial academic environments under the terms of
    the APL as published by the QBlade project; See the file 'LICENSE'
    for details.

***********************************************************************/

#ifndef SENSORCSVDOCK_H
#define SENSORCSVDOCK_H

#include <QDockWidget>

class QSlider;
class QPushButton;
class QLabel;
class QTimer;
class QCheckBox;

class SensorCsvDock : public QDockWidget
{
    Q_OBJECT

public:
    explicit SensorCsvDock(QWidget *parent = nullptr);

private slots:
    void OnTimeSliderChanged(int value);
    void OnPlayToggled(bool checked);
    void OnTimerTick();
    void OnDataChanged();
    void OnTimeChanged(double tSec);

private:
    QSlider *m_timeSlider;
    QPushButton *m_playButton;
    QLabel *m_timeLabel;
    QLabel *m_infoLabel;
    QCheckBox *m_showMarkers;
    QTimer *m_timer;
    bool m_bUpdatingSlider = false;
};

#endif // SENSORCSVDOCK_H
