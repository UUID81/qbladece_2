/**********************************************************************

    Copyright (C) 2024 QBlade Sensor CSV extension

    This program is licensed under the Academic Public License
    (APL) v1.0; You can use, redistribute and/or modify it in
    non-commercial academic environments under the terms of
    the APL as published by the QBlade project; See the file 'LICENSE'
    for details.

***********************************************************************/

#include "SensorBladeMarkers.h"
#include "SensorDataManager.h"
#include "src/QTurbine/QTurbine.h"
#include "src/QBEM/Blade.h"
#include "src/QSimulation/QSimulation.h"
#include "src/StructModel/CoordSys.h"
#include "src/Vec3.h"

#include <QtOpenGL>
#include <QHash>
#include <QDateTime>
#include <QColor>
#include <cmath>

extern bool g_sensorMarkersVisible;

void GlDrawSensorMarkers(QTurbine *turb)
{
    SensorDataManager *mgr = SensorDataManager::instance();
    if (!mgr || !mgr->hasData() || !g_sensorMarkersVisible) return;
    if (!turb || !turb->m_Blade) return;
    if (turb->m_numBlades <= 0) return;

    int m = 0;
    if (turb->m_savedHubCoords.size()) m = turb->m_savedHubCoords.size() - 1;
    if (turb->m_QSim)
        if (!turb->m_QSim->m_bIsRunning && turb->m_QSim->m_bStoreReplay && turb->m_QSim->m_shownTimeIndex != -1)
            m = turb->m_QSim->m_shownTimeIndex;
    if (m < 0 || m >= turb->m_savedHubCoords.size()) m = turb->m_savedHubCoords.size() - 1;

    CoordSys hub;
    if (turb->m_savedHubCoords.size()) hub = turb->m_savedHubCoords.at(m);
    else {
        hub.Origin = turb->m_globalPosition + Vec3(0, 0, turb->m_towerHeight);
        hub.X = Vec3(1, 0, 0);
        hub.Y = Vec3(0, 1, 0);
        hub.Z = Vec3(0, 0, 1);
        if (turb->m_bisUpWind) hub.Origin = hub.Origin - hub.X * turb->m_overHang;
        else hub.Origin = hub.Origin + hub.X * turb->m_overHang;
    }

    const double rootRadius = turb->m_Blade->getRootRadius();
    const double rotorRadius = turb->m_Blade->getRotorRadius();
    const double t = mgr->currentTimeSec();
    const QDateTime ref = mgr->minTime();

    QHash<SensorDataManager::SensorKey, const SensorDataManager::Sample*> current;

    QList<SensorDataManager::SensorKey> keys = mgr->sensorKeys();
    for (const SensorDataManager::SensorKey &key : keys) {
        if (key.bladeIndex < 0 || key.bladeIndex >= turb->m_numBlades) continue;
        QList<SensorDataManager::Sample> ss = mgr->samplesForSensor(key);
        if (ss.isEmpty()) continue;
        const SensorDataManager::Sample *best = nullptr;
        double bestD = 1e30;
        for (const SensorDataManager::Sample &s : ss) {
            double dt = std::fabs(ref.msecsTo(s.timeStamp) / 1000.0 - t);
            if (dt < bestD) { bestD = dt; best = &s; }
        }
        if (best) current[key] = best;
    }

    if (current.isEmpty()) return;

    glPushAttrib(GL_ALL_ATTRIB_BITS);
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_LIGHTING);
    glDisable(GL_CULL_FACE);

    const double markerRadius = rotorRadius / 60.0;

    for (auto it = current.constBegin(); it != current.constEnd(); ++it) {
        const SensorDataManager::SensorKey &key = it.key();
        const SensorDataManager::Sample *s = it.value();

        CoordSys bladeCoord = hub;
        Vec3 coneaxis = bladeCoord.Y;
        if (turb->m_bisUpWind) bladeCoord.RotateAxesN(coneaxis, -turb->m_rotorConeAngle);
        else bladeCoord.RotateAxesN(coneaxis, turb->m_rotorConeAngle);
        bladeCoord.RotateAxesN(hub.X, 360.0 / turb->m_numBlades * key.bladeIndex);

        double r = key.radius;
        if (r < rootRadius) r = rootRadius;
        if (r > rotorRadius) r = rotorRadius;

        Vec3 localPos = bladeCoord.Origin + bladeCoord.Z * r;

        QColor col = SensorDataManager::categoryColor(s->category);

        glPushMatrix();
        glTranslated(localPos.x, localPos.y, localPos.z);
        glColor4d(col.redF(), col.greenF(), col.blueF(), 1.0);
        const int NS = 12;
        for (int axis = 0; axis < 3; ++axis) {
            glBegin(GL_TRIANGLE_FAN);
            glVertex3d(0, 0, 0);
            for (int j = 0; j <= NS; ++j) {
                double a = 2.0 * M_PI * j / NS;
                double x = markerRadius * std::cos(a);
                double y = markerRadius * std::sin(a);
                if (axis == 0)      glVertex3d(x, y, 0);
                else if (axis == 1) glVertex3d(x, 0, y);
                else                glVertex3d(0, x, y);
            }
            glEnd();
        }
        glPopMatrix();

        Vec3 up = bladeCoord.Y;
        glLineWidth(2.0f);
        glBegin(GL_LINES);
        glColor4d(col.redF(), col.greenF(), col.blueF(), 0.9);
        glVertex3d(localPos.x, localPos.y, localPos.z);
        glVertex3d(localPos.x + up.x * markerRadius * 2.0,
                   localPos.y + up.y * markerRadius * 2.0,
                   localPos.z + up.z * markerRadius * 2.0);
        glEnd();
    }

    glPopAttrib();
}
