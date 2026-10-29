/**********************************************************************

    Copyright (C) 2024 QBlade Sensor CSV extension

    This program is licensed under the Academic Public License
    (APL) v1.0; You can use, redistribute and/or modify it in
    non-commercial academic environments under the terms of
    the APL as published by the QBlade project; See the file 'LICENSE'
    for details.

***********************************************************************/

#include "SensorDataManager.h"
#include <QFile>
#include <QTextStream>
#include <QFileInfo>
#include <QHash>
#include <QSet>
#include <QtGlobal>
#include <cmath>

SensorDataManager *SensorDataManager::s_instance = nullptr;

SensorDataManager::SensorDataManager(QObject *parent) : QObject(parent)
{
}

SensorDataManager* SensorDataManager::instance()
{
    if (!s_instance) s_instance = new SensorDataManager();
    return s_instance;
}

QColor SensorDataManager::categoryColor(Category c)
{
    switch (c) {
    case CAT_L: return QColor(0, 204, 0);      // green
    case CAT_M: return QColor(255, 204, 0);    // yellow
    case CAT_H: return QColor(255, 0, 0);      // red
    default:    return QColor(160, 160, 160); // grey
    }
}

SensorDataManager::Category SensorDataManager::categoryFromString(const QString &s)
{
    QString t = s.trimmed().toUpper();
    if (t == "L" || t == "LOW") return CAT_L;
    if (t == "M" || t == "MED" || t == "MEDIUM") return CAT_M;
    if (t == "H" || t == "HIGH") return CAT_H;
    return CAT_NONE;
}

int SensorDataManager::bladeIndexFromString(const QString &s)
{
    QString t = s.trimmed().toUpper();
    if (t.isEmpty()) return -1;
    if (t.size() == 1 && t.at(0) >= 'A' && t.at(0) <= 'Z') return t.at(0).unicode() - 'A';
    bool ok = false;
    int n = t.toInt(&ok);
    if (ok) {
        if (n >= 1) return n - 1;   // "1" -> blade 0
        return -1;
    }
    if (t.startsWith("BLADE")) {
        QString num = t.mid(5).trimmed();
        if (num.startsWith('_')) num = num.mid(1);
        n = num.toInt(&ok);
        if (ok && n >= 1) return n - 1;
    }
    return -1;
}

SensorDataManager::Category SensorDataManager::deduceCategory(double magZ, double absMax)
{
    if (absMax <= 0.0) return CAT_L;
    double v = std::fabs(magZ) / absMax;
    if (v < 0.33) return CAT_L;
    if (v < 0.66) return CAT_M;
    return CAT_H;
}

static QDateTime parseTimeStamp(const QString &s)
{
    QString t = s.trimmed();
    QDateTime dt = QDateTime::fromString(t, "yyyy-MM-dd HH:mm:ss.zzz");
    if (!dt.isValid()) dt = QDateTime::fromString(t, "yyyy-MM-dd HH:mm:ss");
    if (!dt.isValid()) dt = QDateTime::fromString(t, Qt::ISODate);
    return dt;
}

bool SensorDataManager::loadCsvFile(const QString &fileName, QString *errMsg)
{
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (errMsg) *errMsg = QObject::tr("Could not open file: %1").arg(fileName);
        return false;
    }

    QTextStream in(&file);
    QString header = in.readLine();
    QStringList headers = header.split(',');
    if (headers.size() < 5 && header.contains(';')) headers = header.split(';');
    int idxTs = headers.indexOf("timestamp");
    int idxBlade = headers.indexOf("Blade");
    int idxRadius = headers.indexOf("Radius");
    int idxMagZ = headers.indexOf("MagZ");
    int idxCat = headers.indexOf("MagZ_category");
    int idxPitch = headers.indexOf("BladePitch");
    int idxWind = headers.indexOf("WindSpeed");
    if (idxTs < 0) idxTs = 0;
    if (idxBlade < 0) idxBlade = 1;
    if (idxRadius < 0) idxRadius = 2;
    if (idxMagZ < 0) idxMagZ = 3;
    if (idxCat < 0) idxCat = 4;

    QList<Sample> newSamples;
    int lineNo = 1;
    int skipped = 0;

    while (!in.atEnd()) {
        lineNo++;
        QString line = in.readLine().trimmed();
        if (line.isEmpty()) continue;

        QStringList parts = line.split(',');
        if (parts.size() < 5 && line.contains(';'))
            parts = line.split(';');

        if (parts.size() < 5) { skipped++; continue; }

        Sample s;
        s.rawLine = line;
        s.timeStamp = parseTimeStamp(parts.at(idxTs));
        if (!s.timeStamp.isValid()) { skipped++; continue; }

        s.bladeIndex = bladeIndexFromString(parts.at(idxBlade));
        if (s.bladeIndex < 0) { skipped++; continue; }

        bool okR = false, okM = false;
        s.radius = parts.at(idxRadius).trimmed().toDouble(&okR);
        s.magZ = parts.at(idxMagZ).trimmed().toDouble(&okM);
        if (!okR || !okM || s.radius <= 0.0) { skipped++; continue; }

        s.category = (idxCat < parts.size()) ? categoryFromString(parts.at(idxCat)) : CAT_NONE;

        s.bladePitch = (idxPitch >= 0 && idxPitch < parts.size()) ? parts.at(idxPitch).trimmed().toDouble() : 0.0;
        s.windSpeed = (idxWind >= 0 && idxWind < parts.size()) ? parts.at(idxWind).trimmed().toDouble() : 0.0;

        newSamples.append(s);
    }
    file.close();

    if (newSamples.isEmpty()) {
        if (errMsg) *errMsg = QObject::tr("No valid sensor samples found in %1 (%2 lines skipped)").arg(fileName).arg(skipped);
        return false;
    }

    double absMax = 0.0;
    for (const Sample &s : newSamples) absMax = std::max(absMax, std::fabs(s.magZ));
    for (Sample &s : newSamples) {
        if (s.category == CAT_NONE) s.category = deduceCategory(s.magZ, absMax);
    }

    m_samples.append(newSamples);
    std::sort(m_samples.begin(), m_samples.end(),
              [](const Sample &a, const Sample &b) { return a.timeStamp < b.timeStamp; });

    m_minTime = m_samples.first().timeStamp;
    m_maxTime = m_samples.last().timeStamp;
    m_absMaxMagZ = std::max(m_absMaxMagZ, absMax);
    m_currentTimeSec = 0.0;

    emit dataChanged();
    emit timeChanged(m_currentTimeSec);
    return true;
}

void SensorDataManager::clearAll()
{
    m_samples.clear();
    m_minTime = QDateTime();
    m_maxTime = QDateTime();
    m_currentTimeSec = 0.0;
    m_absMaxMagZ = 0.0;
    m_playing = false;
    emit dataChanged();
    emit timeChanged(0.0);
    emit playbackStateChanged(false);
}

QList<SensorDataManager::SensorKey> SensorDataManager::sensorKeys() const
{
    QSet<SensorKey> keys;
    QList<SensorKey> ordered;
    for (const Sample &s : m_samples) {
        SensorKey k;
        k.bladeIndex = s.bladeIndex;
        k.radius = s.radius;
        if (!keys.contains(k)) {
            keys.insert(k);
            ordered.append(k);
        }
    }
    return ordered;
}

QList<SensorDataManager::Sample> SensorDataManager::samplesForSensor(const SensorKey &key) const
{
    QList<Sample> out;
    for (const Sample &s : m_samples)
        if (s.bladeIndex == key.bladeIndex && qFuzzyCompare(s.radius, key.radius))
            out.append(s);
    return out;
}

void SensorDataManager::setCurrentTimeSec(double t)
{
    double dur = durationSec();
    if (dur > 0.0) t = qBound(0.0, t, dur);
    else t = 0.0;
    if (qFuzzyCompare(t, m_currentTimeSec)) return;
    m_currentTimeSec = t;
    emit timeChanged(m_currentTimeSec);
}

double SensorDataManager::durationSec() const
{
    if (!m_minTime.isValid() || !m_maxTime.isValid()) return 0.0;
    return m_minTime.msecsTo(m_maxTime) / 1000.0;
}

void SensorDataManager::setPlaying(bool p)
{
    if (m_playing == p) return;
    m_playing = p;
    emit playbackStateChanged(m_playing);
}

uint qHash(const SensorDataManager::SensorKey &key)
{
    return ::qHash(key.bladeIndex) ^ ::qHash(int(key.radius * 1000.0));
}
