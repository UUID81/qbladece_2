/**********************************************************************

    Copyright (C) 2024 QBlade Sensor CSV extension

    This program is licensed under the Academic Public License
    (APL) v1.0; You can use, redistribute and/or modify it in
    non-commercial academic environments under the terms of
    the APL as published by the QBlade project; See the file 'LICENSE'
    for details.

***********************************************************************/

#ifndef SENSORDATAMANAGER_H
#define SENSORDATAMANAGER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <QDateTime>
#include <QColor>

class SensorDataManager : public QObject
{
    Q_OBJECT

public:
    enum Category { CAT_NONE = -1, CAT_L = 0, CAT_M = 1, CAT_H = 2 };

    struct Sample {
        QDateTime timeStamp;
        int bladeIndex;       // 0-based blade index (A=0, B=1, C=2, ...)
        double radius;        // sensor radius along the blade [m]
        double magZ;          // raw MagZ value
        Category category;    // L / M / H
        double bladePitch;    // optional context data
        double windSpeed;     // optional context data
        QString rawLine;
    };

    struct SensorKey {
        int bladeIndex;
        double radius;
        bool operator==(const SensorKey &o) const { return bladeIndex == o.bladeIndex && qFuzzyCompare(radius, o.radius); }
    };

    explicit SensorDataManager(QObject *parent = nullptr);

    bool loadCsvFile(const QString &fileName, QString *errMsg = nullptr);
    void clearAll();

    bool hasData() const { return !m_samples.isEmpty(); }
    int sampleCount() const { return m_samples.size(); }

    QList<SensorKey> sensorKeys() const;
    QList<Sample> samplesForSensor(const SensorKey &key) const;

    QDateTime minTime() const { return m_minTime; }
    QDateTime maxTime() const { return m_maxTime; }

    double currentTimeSec() const { return m_currentTimeSec; }
    void setCurrentTimeSec(double t);
    double durationSec() const;

    bool isPlaying() const { return m_playing; }
    void setPlaying(bool p);

    static QColor categoryColor(Category c);
    static Category categoryFromString(const QString &s);
    static int bladeIndexFromString(const QString &s);

    static SensorDataManager* instance();

signals:
    void dataChanged();
    void timeChanged(double tSec);
    void playbackStateChanged(bool playing);

private:
    static Category deduceCategory(double magZ, double absMax);

    QList<Sample> m_samples;
    QDateTime m_minTime, m_maxTime;
    double m_currentTimeSec = 0.0;
    bool m_playing = false;
    double m_absMaxMagZ = 0.0;

    static SensorDataManager *s_instance;
};

uint qHash(const SensorDataManager::SensorKey &key);

#endif // SENSORDATAMANAGER_H
