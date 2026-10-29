/**********************************************************************

    Copyright (C) 2024 QBlade Sensor CSV extension

    This program is licensed under the Academic Public License
    (APL) v1.0; You can use, redistribute and/or modify it in
    non-commercial academic environments under the terms of
    the APL as published by the QBlade project; See the file 'LICENSE'
    for details.

***********************************************************************/

#include "SensorCsvDock.h"
#include "SensorDataManager.h"
#include "src/MainFrame.h"
#include "src/GLWidget.h"

bool g_sensorMarkersVisible = true;

#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QSlider>
#include <QPushButton>
#include <QLabel>
#include <QCheckBox>
#include <QTimer>
#include <QDateTime>

SensorCsvDock::SensorCsvDock(QWidget *parent) : QDockWidget(tr("Sensor CSV Data"), parent)
{
    setObjectName("SensorCsvDock");
    setAllowedAreas(Qt::BottomDockWidgetArea | Qt::TopDockWidgetArea);

    QWidget *w = new QWidget(this);
    QVBoxLayout *layout = new QVBoxLayout(w);

    m_infoLabel = new QLabel(tr("No sensor CSV loaded."), w);
    layout->addWidget(m_infoLabel);

    QHBoxLayout *sliderRow = new QHBoxLayout();
    m_playButton = new QPushButton(tr("Play"), w);
    m_playButton->setCheckable(true);
    m_playButton->setEnabled(false);
    sliderRow->addWidget(m_playButton);

    m_timeSlider = new QSlider(Qt::Horizontal, w);
    m_timeSlider->setRange(0, 1000);
    m_timeSlider->setEnabled(false);
    sliderRow->addWidget(m_timeSlider, 1);

    m_timeLabel = new QLabel("0.000 s", w);
    m_timeLabel->setMinimumWidth(90);
    sliderRow->addWidget(m_timeLabel);
    layout->addLayout(sliderRow);

    m_showMarkers = new QCheckBox(tr("Show sensor markers on blades"), w);
    m_showMarkers->setChecked(true);
    layout->addWidget(m_showMarkers);

    QHBoxLayout *legend = new QHBoxLayout();
    QLabel *l1 = new QLabel(tr("  L = Low"), w);  l1->setStyleSheet("color: rgb(0,204,0); font-weight: bold;");
    QLabel *l2 = new QLabel(tr("  M = Medium"), w); l2->setStyleSheet("color: rgb(204,164,0); font-weight: bold;");
    QLabel *l3 = new QLabel(tr("  H = High"), w);  l3->setStyleSheet("color: rgb(255,0,0); font-weight: bold;");
    legend->addWidget(l1); legend->addWidget(l2); legend->addWidget(l3);
    legend->addStretch(1);
    layout->addLayout(legend);

    setWidget(w);

    m_timer = new QTimer(this);
    m_timer->setInterval(20); // 50 Hz playback

    connect(m_timeSlider, SIGNAL(valueChanged(int)), this, SLOT(OnTimeSliderChanged(int)));
    connect(m_playButton, SIGNAL(toggled(bool)), this, SLOT(OnPlayToggled(bool)));
    connect(m_timer, SIGNAL(timeout()), this, SLOT(OnTimerTick()));
    connect(m_showMarkers, &QCheckBox::toggled, this, [](bool checked){
        g_sensorMarkersVisible = checked;
        if (g_mainFrame && g_mainFrame->getGlWidget()) g_mainFrame->getGlWidget()->update();
    });

    SensorDataManager *mgr = SensorDataManager::instance();
    connect(mgr, SIGNAL(dataChanged()), this, SLOT(OnDataChanged()));
    connect(mgr, SIGNAL(timeChanged(double)), this, SLOT(OnTimeChanged(double)));

    OnDataChanged();
}

void SensorCsvDock::OnDataChanged()
{
    SensorDataManager *mgr = SensorDataManager::instance();
    if (!mgr->hasData()) {
        m_infoLabel->setText(tr("No sensor CSV loaded."));
        m_timeSlider->setEnabled(false);
        m_playButton->setEnabled(false);
        m_timer->stop();
        m_playButton->setChecked(false);
        hide();
        return;
    }
    show();
    m_timeSlider->setEnabled(true);
    m_playButton->setEnabled(true);
    int nSensors = mgr->sensorKeys().size();
    m_infoLabel->setText(tr("%1 samples, %2 sensors, duration %3 s")
                         .arg(mgr->sampleCount())
                         .arg(nSensors)
                         .arg(mgr->durationSec(), 0, 'f', 2));
    if (g_mainFrame && g_mainFrame->getGlWidget()) g_mainFrame->getGlWidget()->update();
}

void SensorCsvDock::OnTimeChanged(double tSec)
{
    SensorDataManager *mgr = SensorDataManager::instance();
    double dur = mgr->durationSec();
    m_timeLabel->setText(QString("%1 s / %2 s")
                         .arg(tSec, 0, 'f', 3)
                         .arg(dur, 0, 'f', 2));
    if (!m_bUpdatingSlider && dur > 0.0) {
        m_bUpdatingSlider = true;
        m_timeSlider->setValue(int(tSec / dur * 1000.0));
        m_bUpdatingSlider = false;
    }
    if (g_mainFrame && g_mainFrame->getGlWidget()) g_mainFrame->getGlWidget()->update();
}

void SensorCsvDock::OnTimeSliderChanged(int value)
{
    if (m_bUpdatingSlider) return;
    SensorDataManager *mgr = SensorDataManager::instance();
    double dur = mgr->durationSec();
    if (dur <= 0.0) return;
    mgr->setCurrentTimeSec(value / 1000.0 * dur);
}

void SensorCsvDock::OnPlayToggled(bool checked)
{
    SensorDataManager *mgr = SensorDataManager::instance();
    mgr->setPlaying(checked);
    m_playButton->setText(checked ? tr("Pause") : tr("Play"));
    if (checked) m_timer->start();
    else m_timer->stop();
}

void SensorCsvDock::OnTimerTick()
{
    SensorDataManager *mgr = SensorDataManager::instance();
    double dur = mgr->durationSec();
    if (dur <= 0.0) return;
    double t = mgr->currentTimeSec() + m_timer->interval() / 1000.0;
    if (t >= dur) {
        t = dur;
        m_timer->stop();
        m_playButton->setChecked(false);
        mgr->setPlaying(false);
        m_playButton->setText(tr("Play"));
    }
    mgr->setCurrentTimeSec(t);
}
