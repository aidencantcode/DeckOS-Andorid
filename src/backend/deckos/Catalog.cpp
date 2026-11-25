// DeckOS
// See Catalog.h

#include "Catalog.h"

#include "Log.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>


namespace deckos {

const CatalogEmulator* CatalogSystem::emulator(const QString& emu_id) const
{
    for (const CatalogEmulator& emu : emulators) {
        if (emu.id == emu_id)
            return &emu;
    }
    return nullptr;
}

const Catalog& Catalog::instance()
{
    static const Catalog catalog(QStringLiteral(":/deckos/catalog/systems.json"));
    return catalog;
}

QString Catalog::normalized(const QString& text)
{
    QString out;
    for (const QChar ch : text.toLower()) {
        if (ch.isLetterOrNumber())
            out += ch;
    }
    return out;
}

Catalog::Catalog(const QString& json_path)
{
    QFile file(json_path);
    if (!file.open(QIODevice::ReadOnly)) {
        Log::warning(QStringLiteral("DeckOS"), LOGMSG("System catalog `%1` missing").arg(json_path));
        return;
    }
    const QJsonArray systems = QJsonDocument::fromJson(file.readAll()).object().value(QStringLiteral("systems")).toArray();
    m_systems.reserve(systems.size());

    for (const QJsonValue& sys_val : systems) {
        const QJsonObject obj = sys_val.toObject();
        CatalogSystem sys;
        sys.id = obj.value(QStringLiteral("id")).toString();
        sys.name = obj.value(QStringLiteral("name")).toString();
        sys.shortName = obj.value(QStringLiteral("shortName")).toString();
        sys.multidisc = obj.value(QStringLiteral("multidisc")).toBool();
        sys.raConsoleId = obj.value(QStringLiteral("raConsoleId")).toInt();
        for (const QJsonValue& v : obj.value(QStringLiteral("folders")).toArray())
            sys.folders << v.toString();
        for (const QJsonValue& v : obj.value(QStringLiteral("extensions")).toArray())
            sys.extensions << v.toString().toLower();
        for (const QJsonValue& emu_val : obj.value(QStringLiteral("emulators")).toArray()) {
            const QJsonObject e = emu_val.toObject();
            CatalogEmulator emu;
            emu.id = e.value(QStringLiteral("id")).toString();
            emu.name = e.value(QStringLiteral("name")).toString();
            emu.package = e.value(QStringLiteral("package")).toString();
            emu.args = e.value(QStringLiteral("args")).toString();
            emu.isDefault = e.value(QStringLiteral("isDefault")).toBool();
            emu.retroArch = e.value(QStringLiteral("retroArch")).toBool();
            emu.achievements = e.value(QStringLiteral("achievements")).toBool();
            sys.emulators.append(emu);
        }
        if (sys.id.isEmpty())
            continue;

        const int index = m_systems.size();
        m_by_id.insert(sys.id, index);
        // the id and the short name count as folder names too; the first system to claim a name keeps it
        QStringList names = sys.folders;
        names << sys.id << sys.shortName;
        for (const QString& name : names) {
            const QString key = normalized(name);
            if (!key.isEmpty() && !m_by_folder.contains(key))
                m_by_folder.insert(key, index);
        }
        m_systems.append(std::move(sys));
    }
}

const CatalogSystem* Catalog::byId(const QString& id) const
{
    const auto it = m_by_id.constFind(id);
    return it == m_by_id.cend() ? nullptr : &m_systems.at(it.value());
}

const CatalogSystem* Catalog::byFolderName(const QString& folder_name) const
{
    const auto it = m_by_folder.constFind(normalized(folder_name));
    return it == m_by_folder.cend() ? nullptr : &m_systems.at(it.value());
}


QString launch_command(const CatalogEmulator& emu)
{
    QString args = emu.args;
    if (emu.retroArch && !emu.package.isEmpty()) {
        // --es LIBRETRO "snes9x" -> --es LIBRETRO "/data/data/<package>/cores/snes9x_libretro_android.so"
        static const QRegularExpression core(QStringLiteral("(--es\\s+LIBRETRO\\s+\")([^\"/][^\"]*)(\")"));
        const QRegularExpressionMatch m = core.match(args);
        if (m.hasMatch()) {
            QString name = m.captured(2);
            if (!name.endsWith(QLatin1String("_libretro_android.so")))
                name += QStringLiteral("_libretro_android.so");
            args.replace(m.capturedStart(2), m.capturedLength(2),
                         QStringLiteral("/data/data/") + emu.package + QStringLiteral("/cores/") + name);
        }
    }
    return QStringLiteral("am start ") + args;
}

} // namespace deckos
