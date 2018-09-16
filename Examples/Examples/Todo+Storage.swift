//
//  Todo+Storage.swift
//  RxFeedback
//
//  Created by Krunoslav Zaher on 5/11/17.
//  Copyright © 2017 Krunoslav Zaher. All rights reserved.
//

struct Storage<Entity: Identifiable> {
    fileprivate var entities: [Entity.Identifier: Entity] = [:]
}

extension Storage {
    func sorted(by: (Entity, Entity) -> Bool) -> [Entity] {
        return entities.values.sorted(by: by)
    }

    func sorted<Key: Comparable>(key: (Entity) -> Key) -> [Entity] {
        return entities.values.sorted(by: { key($0) < key($1) })
    }
}

extension Storage where Entity: Syncable {
    func mutate(entity: Entity, transform: (Entity) -> Entity) -> Storage {
        let latestEntity = self.entities[entity.id] ?? entity

        let finalResult = transform(Entity.setSync(.syncing)(latestEntity))
        var newStorage = self
        newStorage.entities[finalResult.id] = finalResult
        if finalResult.id != entity.id {
            fatalError("Id changed")
        }
        return newStorage
    }
}
